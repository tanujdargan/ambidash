import AppIntents

#if canImport(AlarmKit)
import AlarmKit

/// GENTLE TIMELINE ALARMS — the Stop / Snooze App Intents wired to an opt-in
/// AlarmKit block-start alarm (iOS 26+). They live in the widget extension (an
/// `app-extension` target, iOS-only) alongside the other widget intents so the
/// system can run them from the Lock Screen / Dynamic Island without fully
/// foregrounding the app.
///
/// `StopBlockAlarmIntent` stops the alerting alarm; `SnoozeBlockAlarmIntent`
/// restarts it as a short countdown (the `.countdown` secondary-button behavior /
/// `postAlert` duration on the configuration). Both are no-ops on a nil/invalid id
/// rather than crashing, so a stale Live Activity button can never trap the user.
@available(iOS 26.1, *)
struct StopBlockAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        return .result()
    }
}

@available(iOS 26.1, *)
struct SnoozeBlockAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            // Restart the alarm as a short countdown (snooze).
            try? AlarmManager.shared.countdown(id: id)
        }
        return .result()
    }
}
#endif
