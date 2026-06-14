import AppIntents
import SwiftData
import WidgetKit

// Phase 0 (spine #2 — one capture) — capture a thought from ANYWHERE outside the app:
// Siri, the Shortcuts app, a Lock Screen / Home Screen action, or a widget button.
// Reuses the same on-disk store + CaptureService as in-app capture, so an externally
// captured thought lands in the very same inbox to be triaged later. No new target,
// no network — runs in-process against the shared container.
struct CaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a thought"
    static let description = IntentDescription(
        "Dump a thought into your AmbiDash inbox — no category needed, triage it later."
    )
    /// Background capture: never yanks the user into the app for a <2s dump.
    static let openAppWhenRun = false

    @Parameter(title: "Thought")
    var text: String

    init() {}
    init(text: String) { self.text = text }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "That looked empty — nothing captured.")
        }
        // CaptureService is @MainActor-isolated; hop to the main actor for the write.
        let captured: Bool = try await MainActor.run {
            let context = ModelContext(try LogProgressIntent.sharedContainer())
            return CaptureService.capture(trimmed, source: .widget, in: context) != nil
        }
        guard captured else {
            return .result(dialog: "Couldn't capture that — try again?")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Captured. It's in your inbox.")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$text)")
    }
}
