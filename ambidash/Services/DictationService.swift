import Foundation

#if os(iOS)
@preconcurrency import Speech
@preconcurrency import AVFoundation

/// VOICE DICTATION (on-device, WisprFlow-style).
///
/// A reusable, `@Observable` controller that streams LIVE partial transcription
/// straight into a bound text field. Everything runs ON-DEVICE — there is NEVER a
/// network/cloud round-trip — to honor the app's privacy-by-construction mandate.
///
/// Two tiers, chosen at runtime:
///   • Tier 1 (iOS 26+): the modern `SpeechAnalyzer` + `SpeechTranscriber` pipeline,
///     fed `AVAudioEngine` buffers, consuming streaming results.
///   • Tier 2 (iOS 17–25): `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest`
///     with `requiresOnDeviceRecognition = true` and live partial results, fed by an
///     `AVAudioEngine` input-node tap.
///
/// If on-device recognition is unavailable (older/locale-restricted devices), the
/// controller surfaces `.unavailable` and the mic affordance disables itself — we
/// NEVER silently fall back to server recognition.
///
/// One controller drives one text field session at a time. Each Reflect surface
/// (ReflectView's three questions, ClosingRitual's felt-note + one-thing) owns its
/// own instance via `@State`, so dictation is naturally per-field.
@MainActor
@Observable
final class DictationService {

    enum Status: Equatable {
        case idle
        case requestingPermission
        case preparing       // downloading/installing the on-device speech model
        case recording
        case denied          // mic or speech authorization refused
        case unavailable     // on-device recognition not supported here
        case error(String)
    }

    /// Live transcript for the CURRENT session only (reset on each `start`). The view
    /// diffs this against what it has already committed and appends the delta into the
    /// bound field, so typed text is augmented, never replaced.
    private(set) var transcript: String = ""
    private(set) var status: Status = .idle

    var isRecording: Bool { status == .recording }

    /// Whether a mic affordance should even be offered. Disabled when the device can't
    /// do on-device recognition for the current locale.
    var isAvailable: Bool {
        guard let recognizer = SFSpeechRecognizer() else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    private let audioEngine = AVAudioEngine()
    private var sfRecognizer: SFSpeechRecognizer?
    private var sfRequest: SFSpeechAudioBufferRecognitionRequest?
    private var sfTask: SFSpeechRecognitionTask?

    // Tier-1 (iOS 26+) handles, type-erased to avoid hard-linking symbols on older SDKs.
    private var modernSession: AnyObject?

    // MARK: - Lifecycle

    /// Begins a fresh dictation session. Requests Speech + Microphone authorization
    /// gently (only here, on first tap). Safe to call when already recording (no-op).
    func start() async {
        guard status == .idle || status == .denied || status == .unavailable
                || { if case .error = status { return true }; return false }()
        else { return }
        transcript = ""

        status = .requestingPermission
        guard await requestAuthorization() else {
            status = .denied
            return
        }

        guard isAvailable else {
            status = .unavailable
            return
        }

        do {
            if #available(iOS 26.0, *) {
                // The on-device model may need downloading/installing on first use.
                // Surface a distinct "preparing" state so the UI can show progress
                // instead of appearing to hang after permission is granted.
                status = .preparing
                try await startModern()
            } else {
                try startLegacy()
            }
            status = .recording
        } catch DictationError.modelUnavailable {
            // The on-device speech model couldn't be installed (e.g. no connectivity
            // on first use). Surface as unavailable rather than a raw error string.
            stop()
            status = .unavailable
        } catch let error as NSError where error.domain == NSURLErrorDomain {
            // Model asset download failed due to a network problem. The user's audio
            // never leaves the device — only the model asset is fetched — so frame this
            // as the model not being ready yet, not a privacy/recognition failure.
            stop()
            status = .unavailable
        } catch {
            stop()
            status = .error(error.localizedDescription)
        }
    }

    /// Ends the current session and tears down audio + recognition. Idempotent.
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // Always remove the tap, even when the engine never started. A partially-failed
        // start() — e.g. installTap() succeeded but the subsequent engine.start() threw
        // (routine on the Simulator, which has no real audio input) — leaves the tap in
        // place while the engine is stopped. The NEXT installTap() on the same bus then
        // traps with "only one tap may be installed per bus", a hard crash on the user's
        // second dictation attempt. removeTap on an un-tapped bus is a safe no-op.
        audioEngine.inputNode.removeTap(onBus: 0)

        sfRequest?.endAudio()
        sfTask?.cancel()
        sfTask = nil
        sfRequest = nil
        sfRecognizer = nil

        if #available(iOS 26.0, *) {
            stopModern()
        }

        deactivateSession()

        if status == .recording || status == .requestingPermission || status == .preparing {
            status = .idle
        }
    }

    /// Toggle helper for a press/tap mic button.
    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    // MARK: - Authorization

    /// `nonisolated` is load-bearing: the class is `@MainActor`, so without it the
    /// trailing completion closures below inherit MainActor isolation. But TCC invokes
    /// `requestAuthorization`/`requestRecordPermission` completions on an arbitrary
    /// BACKGROUND queue, and under Swift 6 the runtime's executor check then traps
    /// (`_swift_task_checkIsolated` → `dispatch_assert_queue_fail`) — a hard SIGTRAP
    /// crash the moment the user taps the mic. Making the method non-isolated (it
    /// touches no `self` state) plus `@Sendable` completions keeps the callbacks free
    /// of MainActor isolation; the `await` resumes the caller back on the MainActor.
    nonisolated private func requestAuthorization() async -> Bool {
        // Speech recognition authorization.
        let speechGranted: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable authStatus in
                cont.resume(returning: authStatus == .authorized)
            }
        }
        guard speechGranted else { return false }

        // Microphone authorization.
        let micGranted: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { @Sendable granted in
                cont.resume(returning: granted)
            }
        }
        return micGranted
    }

    // MARK: - Audio session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // `.duckOthers` is only valid with `.playAndRecord`/`.playback`/`.multiRoute`.
        // Combining it with `.record` makes `setCategory` throw on iOS, aborting the
        // whole dictation start. Pure `.record` + `.measurement` is the correct config
        // for on-device speech capture (a recording session interrupts other audio
        // anyway, which is the expected behavior while dictating).
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Tier 2 (iOS 17–25): SFSpeechRecognizer

    private func startLegacy() throws {
        let recognizer = SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw DictationError.recognizerUnavailable
        }
        recognizer.defaultTaskHint = .dictation
        sfRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true   // PRIVACY: never leaves the device.
        sfRequest = request

        try configureSession()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw DictationError.recognizerUnavailable
        }
        // Defensive: clear any tap left by a prior partially-failed session before
        // installing, so we never trap on a double-install of bus 0.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.sfRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        sfTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in self.transcript = text }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    if self.status == .recording { self.stop() }
                }
            }
        }
    }

    // MARK: - Tier 1 (iOS 26+): SpeechAnalyzer / SpeechTranscriber

    @available(iOS 26.0, *)
    private func startModern() async throws {
        let session = try await ModernDictationSession()
        session.onUpdate = { [weak self] text in self?.transcript = text }
        session.onFinish = { [weak self] in
            guard let self else { return }
            if self.status == .recording { self.stop() }
        }
        try configureSession()
        try await session.start(engine: audioEngine)
        modernSession = session
    }

    @available(iOS 26.0, *)
    private func stopModern() {
        (modernSession as? ModernDictationSession)?.finish()
        modernSession = nil
    }
}

enum DictationError: LocalizedError {
    case recognizerUnavailable
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "On-device dictation isn't available right now."
        case .modelUnavailable: return "The on-device speech model isn't ready."
        }
    }
}

// MARK: - Modern (iOS 26+) streaming session

/// Wraps the iOS 26 `SpeechAnalyzer` + `SpeechTranscriber` streaming pipeline. Kept
/// in its own `@available` type so none of its symbols are referenced on older SDKs.
/// Audio buffers from the shared `AVAudioEngine` tap are pushed into the analyzer's
/// input stream; transcriber results (volatile + finalized) are coalesced and pushed
/// back to the controller as the live transcript.
@available(iOS 26.0, *)
@MainActor
private final class ModernDictationSession {
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private var finalizedText: String = ""

    /// Marshalled back onto the MainActor controller (set after init).
    var onUpdate: (@MainActor (String) -> Void)?
    var onFinish: (@MainActor () -> Void)?

    init() async throws {
        let locale = Locale.current
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber
        self.analyzer = SpeechAnalyzer(modules: [transcriber])

        // Ensure the on-device model asset is installed for this locale. Asset
        // availability/download failures — offline first-use, an unsupported locale,
        // or (on the Simulator) transcription assets that simply can't be fetched and
        // report "not subscribed to transcription.<lang>" — are normalized to a clean
        // `.modelUnavailable`. Without this, AssetInventory's raw error string leaks
        // through start()'s generic catch into the user-facing alert.
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            throw DictationError.modelUnavailable
        }
    }

    func start(engine: AVAudioEngine) async throws {
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = continuation

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw DictationError.modelUnavailable
        }

        // Consume transcriber results -> coalesce volatile + finalized text.
        recognizerTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in self.transcriber.results {
                    let piece = String(result.text.characters)
                    if result.isFinal {
                        self.finalizedText += piece
                        self.onUpdate?(self.finalizedText)
                    } else {
                        self.onUpdate?(self.finalizedText + piece)
                    }
                }
            } catch {
                self.onFinish?()
            }
        }

        try await analyzer.start(inputSequence: stream)

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0 else {
            throw DictationError.recognizerUnavailable
        }
        let converter = AVAudioConverter(from: recordingFormat, to: analyzerFormat)

        // Defensive: clear any tap left by a prior partially-failed session before
        // installing, so we never trap on a double-install of bus 0.
        inputNode.removeTap(onBus: 0)

        // The tap fires on a realtime audio thread. Capture ONLY Sendable values
        // (the AsyncStream continuation is Sendable; the converter/format are used
        // single-threaded by the audio engine) and never touch actor state here.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            let outBuffer: AVAudioPCMBuffer
            if let converter {
                let ratio = analyzerFormat.sampleRate / recordingFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
                guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
                nonisolated(unsafe) var fed = false
                var err: NSError?
                converter.convert(to: converted, error: &err) { @Sendable _, statusPtr in
                    if fed {
                        statusPtr.pointee = .noDataNow
                        return nil
                    }
                    fed = true
                    statusPtr.pointee = .haveData
                    return buffer
                }
                if err != nil { return }
                outBuffer = converted
            } else {
                outBuffer = buffer
            }
            continuation.yield(AnalyzerInput(buffer: outBuffer))
        }

        engine.prepare()
        try engine.start()
    }

    func finish() {
        inputBuilder?.finish()
        inputBuilder = nil
        recognizerTask?.cancel()
        recognizerTask = nil
        Task { [analyzer] in try? await analyzer.finalizeAndFinishThroughEndOfInput() }
    }
}
#else

// MARK: - macOS no-op

import Foundation

/// macOS build keeps the symbol available (it lives in shared Services/) but ships a
/// guarded no-op: the live-mic dictation UI is iOS-only. The mac UI is in a separate,
/// excluded target, so this never actually drives any control — it only keeps the
/// shared module compiling.
@MainActor
@Observable
final class DictationService {
    enum Status: Equatable {
        case idle, requestingPermission, preparing, recording, denied, unavailable
        case error(String)
    }

    private(set) var transcript: String = ""
    private(set) var status: Status = .unavailable
    var isRecording: Bool { false }
    var isAvailable: Bool { false }

    func start() async { status = .unavailable }
    func stop() {}
    func toggle() async {}
}
#endif
