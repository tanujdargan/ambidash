import SwiftUI
#if os(iOS)
import UIKit
#endif

/// VOICE DICTATION — reusable mic affordance for any free-text field.
///
/// Drops next to (or over) a `TextField` and streams on-device transcription into the
/// bound `$text` while active. Append-at-cursor semantics: it remembers the text that
/// existed when recording began, plus the slice of transcript it has already written,
/// and only ever appends the new delta — so typed text is augmented, never replaced.
///
/// iOS-only (lives under Views/, which the mac target excludes). Tap to toggle a
/// session; a clear recording state (pulsing red mic) shows while live, and a second
/// tap stops. Gracefully disables itself when on-device recognition is unavailable.
struct DictationMicButton: View {
    @Environment(ThemeManager.self) private var tm
    @Binding var text: String

    @State private var dictation = DictationService()
    /// Snapshot of `text` at the moment recording started (the insertion anchor).
    @State private var baseText: String = ""

    /// Gentle, recoverable permission prompt shown when mic/speech access is refused.
    @State private var showPermissionAlert = false
    /// Surfaced when a session ends in an error so the user isn't left at a silent dead-end.
    @State private var errorMessage: String?

    private var isPreparing: Bool { dictation.status == .preparing }

    var body: some View {
        let t = tm.resolved
        Button {
            Task { await handleTap() }
        } label: {
            ZStack {
                Circle()
                    .fill(dictation.isRecording ? t.accent.opacity(0.18) : Color.clear)
                    .frame(width: 30, height: 30)
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(t.muted)
                } else {
                    Image(systemName: dictation.isRecording ? "waveform" : micSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(micColor(t))
                        .symbolEffect(.variableColor.iterative, isActive: dictation.isRecording)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabledForUnavailability)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: dictation.transcript) { _, newValue in
            applyTranscript(newValue)
        }
        .onChange(of: dictation.status) { _, newStatus in
            // When a session ends for any reason, re-anchor for the next one.
            if newStatus == .idle { baseText = text }
            // Surface dead-end states so a refused/failed session is recoverable.
            if newStatus == .denied { showPermissionAlert = true }
            if case .error(let message) = newStatus { errorMessage = message }
        }
        .onDisappear { dictation.stop() }
        .alert("Dictation needs permission", isPresented: $showPermissionAlert) {
            Button("Open Settings") { openSettings() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("To dictate, ambidash needs Microphone and Speech Recognition access. Your voice is transcribed on your device and never leaves your iPhone.")
        }
        .alert(
            "Dictation unavailable",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong with dictation. Please try again.")
        }
    }

    private var accessibilityLabel: String {
        switch dictation.status {
        case .recording: return "Stop dictation"
        case .preparing: return "Preparing dictation"
        default: return "Dictate"
        }
    }

    private var micSymbol: String {
        switch dictation.status {
        case .denied: return "mic.slash"
        case .unavailable: return "mic.slash"
        default: return "mic"
        }
    }

    private var disabledForUnavailability: Bool {
        dictation.status == .unavailable || dictation.status == .preparing
    }

    private func micColor(_ t: ResolvedTheme) -> Color {
        switch dictation.status {
        case .recording: return t.accent
        case .denied, .unavailable: return t.faint
        default: return t.muted
        }
    }

    private func handleTap() async {
        if dictation.isRecording {
            dictation.stop()
            Haptics.light()
        } else if dictation.status == .denied {
            // Permission was previously refused — re-requesting returns the cached
            // denial instantly, so guide the user to Settings instead of silently
            // re-trying.
            showPermissionAlert = true
        } else {
            baseText = text
            Haptics.light()
            await dictation.start()
        }
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// Appends the live transcript onto whatever existed at session start, inserting a
    /// separating space when needed so dictation reads naturally after typed text.
    private func applyTranscript(_ transcript: String) {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else {
            text = baseText
            return
        }
        if baseText.isEmpty {
            text = spoken
        } else {
            let needsSpace = !baseText.hasSuffix(" ") && !baseText.hasSuffix("\n")
            text = baseText + (needsSpace ? " " : "") + spoken
        }
    }
}
