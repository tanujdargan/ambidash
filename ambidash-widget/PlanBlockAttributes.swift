import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(AlarmKit)
import AlarmKit
#endif

/// The ActivityKit attributes for the Now/Next focus Live Activity.
///
/// This type is compiled into BOTH the app target (which requests/updates/ends
/// the Activity) and the widget extension (which renders the Lock Screen view +
/// Dynamic Island). Because it crosses the target boundary it MUST stay plain
/// `Codable`/`Hashable` and reference NO app-only models or enums — exactly the
/// discipline `WidgetSharedData.swift` already follows. The accent colour is
/// carried as a `domainRaw` string so the widget can map it with its own
/// `WidgetStyle` rather than importing `GoalDomain`.
///
/// `ContentState.blockInterval` is the load-bearing field: the Lock Screen and
/// Dynamic Island render `Text(timerInterval:countsDown:)` against it so the
/// SYSTEM ticks the countdown with zero app wake-ups (see the iOS-26 cheat-sheet
/// §2). The app only has to `update()` at block boundaries and `end(.immediate)`
/// at day's end.
///
/// `ActivityAttributes` is iOS 16.1+. ActivityKit isn't available on macOS, so
/// the whole conformance is gated on `canImport(ActivityKit)`; the plain structs
/// below still compile everywhere (the mac target shares this file via the app
/// sources path) so referencing them from shared code never breaks the mac build.
#if canImport(ActivityKit)
struct PlanBlockAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The current block's clock interval. Rendered with
        /// `Text(timerInterval: blockInterval, countsDown: true)` for a
        /// no-wakeup live countdown.
        var blockInterval: ClosedRange<Date>
        /// Title of the block running right now (the radical-focus "Now").
        var blockTitle: String
        /// Domain raw value for the accent (maps via the widget's WidgetStyle).
        var blockDomainRaw: String
        /// The one upcoming block's title (the "Next"). nil when nothing follows.
        var nextTitle: String?
        /// The next block's start, shown as a small "at HH:mm" hint. nil = none.
        var nextStart: Date?
        /// Count of goal-work blocks still open today (for the minimal island).
        var actionsRemaining: Int
    }

    /// Static, set once when the Activity is requested. The day this Activity is
    /// tracking — lets a stale Activity self-describe and lets the app match the
    /// running Activity to today's plan.
    var dayStart: Date
}
#endif

// MARK: - AlarmKit metadata (iOS 26 unmissable block-start alarm)

/// GENTLE TIMELINE ALARMS — the lightweight metadata carried by an opt-in
/// AlarmKit block-start alarm. Like `PlanBlockAttributes` it crosses the app↔widget
/// boundary (the app schedules the alarm, the widget renders the countdown/paused
/// Live Activity UI via `AlarmAttributes<BlockAlarmMetadata>`), so it stays plain
/// `Codable` and tiny — AlarmKit serializes it with the system Live Activity, so
/// large payloads are forbidden. We carry only the block title; the originating
/// PlannedAction is referenced by the alarm's own UUID, not duplicated here.
///
/// AlarmKit is iOS 26+ and unavailable on macOS, so the conformance is gated on
/// `canImport(AlarmKit)`. The plain struct still compiles everywhere so shared code
/// referencing it never breaks the mac build.
#if canImport(AlarmKit)
struct BlockAlarmMetadata: AlarmMetadata {
    /// The block's title, shown on the alarm's Lock Screen / Dynamic Island UI.
    var blockTitle: String

    init(blockTitle: String) {
        self.blockTitle = blockTitle
    }
}
#endif
