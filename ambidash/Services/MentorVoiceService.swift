import Foundation
import AVFoundation

#if os(iOS)
/// Streams mentor letter audio from the Miso TTS endpoint hosted on Modal.
/// Falls back to on-device `AVSpeechSynthesizer` when the server is unreachable.
///
/// Lifecycle: one instance per view that needs playback. Call `speak(_:)` to start,
/// `stop()` to cancel, `togglePause()` to pause/resume. State is published via the
/// `@Observable` `state` property so SwiftUI reacts automatically.
@MainActor
@Observable
final class MentorVoiceService {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case error(String)
    }

    private(set) var state: PlaybackState = .idle
    var isPlaying: Bool { state == .playing }

    private var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var speechDelegate: SpeechDelegate?
    private var currentTask: Task<Void, Never>?

    private let endpoint = "https://dargantanuj--miso-tts-server-fastapi-app.modal.run/synthesize"

    // MARK: - Public API

    /// Speak a mentor letter's text. Tries the Miso TTS server first; falls back
    /// to on-device synthesis if the request fails.
    func speak(_ text: String) {
        stop()
        state = .loading

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await self.fetchTTSAudio(text: text)
                guard !Task.isCancelled else { return }
                guard audioData.count > 100 else {
                    throw URLError(.zeroByteResource)
                }
                try self.configureAudioSession()
                let audioPlayer = try AVAudioPlayer(data: audioData)
                let delegate = PlayerDelegate { [weak self] in
                    self?.handlePlaybackFinished()
                }
                audioPlayer.delegate = delegate
                self.player = audioPlayer
                self.playerDelegate = delegate
                audioPlayer.play()
                self.state = .playing
            } catch {
                guard !Task.isCancelled else { return }
                print("[MentorVoice] TTS failed, falling back to on-device: \(error)")
                self.speakOnDevice(text)
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
        playerDelegate = nil
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        speechDelegate = nil
        deactivateSession()
        state = .idle
    }

    func togglePause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            state = .paused
        } else {
            player.play()
            state = .playing
        }
    }

    // MARK: - Networking

    // Modal returns a 303 redirect for async function calls. URLSession follows
    // 303 by converting POST→GET (per HTTP spec), which Modal rejects. Use a
    // custom delegate that preserves POST + body through the redirect.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config, delegate: RedirectPreserver(), delegateQueue: nil)
    }()

    private func fetchTTSAudio(text: String) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        request.httpBody = body
        request.timeoutInterval = 180

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            print("[MentorVoice] TTS HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        return data
    }

    private final class RedirectPreserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        nonisolated func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            var redirected = request
            if let original = task.originalRequest {
                redirected.httpMethod = original.httpMethod
                redirected.httpBody = original.httpBody
                if let ct = original.value(forHTTPHeaderField: "content-type") {
                    redirected.setValue(ct, forHTTPHeaderField: "content-type")
                }
            }
            completionHandler(redirected)
        }
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - On-device fallback

    private func speakOnDevice(_ text: String) {
        do {
            try configureAudioSession()
        } catch {
            state = .error("Could not configure audio.")
            return
        }
        let synth = AVSpeechSynthesizer()
        let delegate = SpeechDelegate { [weak self] in
            self?.handlePlaybackFinished()
        }
        synth.delegate = delegate
        speechSynthesizer = synth
        speechDelegate = delegate

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        synth.speak(utterance)
        state = .playing
    }

    // MARK: - Completion

    private func handlePlaybackFinished() {
        player = nil
        playerDelegate = nil
        speechSynthesizer = nil
        speechDelegate = nil
        deactivateSession()
        state = .idle
    }
}

// MARK: - AVAudioPlayerDelegate bridge

/// Non-isolated delegate so the callback (fired on an arbitrary thread by
/// AVAudioPlayer) satisfies Swift 6 Sendable requirements. It posts the
/// completion back to the MainActor via a closure.
private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    private let onFinish: @MainActor @Sendable () -> Void

    init(onFinish: @escaping @MainActor @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in onFinish() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in onFinish() }
    }
}

// MARK: - AVSpeechSynthesizerDelegate bridge

/// Non-isolated delegate for on-device speech fallback completion.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    private let onFinish: @MainActor @Sendable () -> Void

    init(onFinish: @escaping @MainActor @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish() }
    }
}
#else

// MARK: - macOS no-op

/// macOS build keeps the symbol available but ships a no-op: the voice mentor
/// feature is iOS-only. This stub prevents compilation errors in shared code.
@MainActor
@Observable
final class MentorVoiceService {
    enum PlaybackState: Equatable {
        case idle, loading, playing, paused
        case error(String)
    }
    private(set) var state: PlaybackState = .idle
    var isPlaying: Bool { false }
    func speak(_ text: String) {}
    func stop() {}
    func togglePause() {}
}
#endif
