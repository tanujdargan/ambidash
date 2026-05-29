import Foundation

/// Shared App Group constants. The widget and the app communicate exclusively
/// through `UserDefaults(suiteName:)` keyed by these strings — there is no
/// shared SwiftData store (the app's container is the default CloudKit store,
/// which an extension can't safely co-open). Keep these in sync with the
/// matching definitions on the app side (ProgressLogService.swift).
enum WidgetSharedKeys {
    static let appGroup = "group.com.ambidash.app"

    // Legacy scalar keys (kept so the widget still renders if only the old
    // DashboardView.updateWidgetData() snapshot is present).
    static let composite = "widget_composite"
    static let pillars = "widget_pillars"
    static let topGoal = "widget_top_goal"
    static let topStatus = "widget_top_status"

    // Rich JSON snapshot written by ProgressLogService on every log.
    static let snapshot = "widget_snapshot_v1"

    // Tap-to-log inbox: an array of `WidgetLogRequest` the app reconciles into
    // real ProgressLog/Streak writes the next time it is foregrounded.
    static let logInbox = "widget_log_inbox_v1"
}

/// A single goal-linked task surfaced on the widget (sourced from today's
/// DailyPlan actions on the app side). `goalID` lets the interactive
/// tap-to-log button credit the right goal.
struct WidgetTask: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var timeSlot: String
    var durationMinutes: Int
    var goalID: UUID?
    var goalTitle: String
    /// Domain raw value (GoalDomain.rawValue) for the accent dot. Empty when
    /// the action isn't goal-linked.
    var domainRaw: String
    /// True once completed (set by the app, or optimistically by the widget's
    /// tap-to-log button before the app reconciles).
    var isDone: Bool
}

/// A compact multi-goal at-a-glance row.
struct WidgetGoalSummary: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var domainRaw: String
    /// "onTrack" | "needsAttention" | "slipping" | "paused"
    var statusRaw: String
    var neglectDays: Int
    /// 0...1 completion for measurable goals, nil otherwise.
    var percentComplete: Double?
    var streakCount: Int
}

/// The full snapshot the app writes and the widget reads. Versioned via the
/// UserDefaults key so a future shape change can't crash an old widget binary.
struct WidgetVitalsSnapshot: Codable, Hashable {
    var generatedAt: Date
    var compositeScore: Int
    var pillarsActive: Int
    /// Most-neglected active goal (the legacy "top goal" headline).
    var topGoalTitle: String
    var topGoalStatus: String
    /// Today's remaining goal-linked tasks (already filtered to pending on the
    /// app side, sorted by time slot). May be empty.
    var tasks: [WidgetTask]
    /// At-a-glance goal summaries, highest priority first.
    var goals: [WidgetGoalSummary]

    static let empty = WidgetVitalsSnapshot(
        generatedAt: .now,
        compositeScore: 50,
        pillarsActive: 0,
        topGoalTitle: "Open AmbiDash",
        topGoalStatus: "",
        tasks: [],
        goals: []
    )

    /// The single most relevant "next" task — first pending task, used by the
    /// Lock Screen accessory families.
    var nextTask: WidgetTask? {
        tasks.first { !$0.isDone }
    }

    /// Count of tasks still open today.
    var openTaskCount: Int {
        tasks.filter { !$0.isDone }.count
    }
}

/// A pending tap-to-log request recorded by the widget's interactive button.
/// The app drains this inbox on launch/foreground and turns each entry into a
/// real ProgressLogService.logCheckIn write. Encoded into the App Group so it
/// survives the widget process being torn down between taps.
struct WidgetLogRequest: Codable, Identifiable, Hashable {
    var id: UUID
    var goalID: UUID?
    var taskID: UUID?
    var requestedAt: Date
}

/// Read/optimistic-write access to the shared snapshot + the tap-to-log inbox
/// from inside the widget extension.
enum WidgetSharedStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSharedKeys.appGroup)
    }

    /// Loads the rich JSON snapshot, falling back to the legacy scalar keys
    /// (and finally to `.empty`) so the widget always has something to render.
    static func loadSnapshot() -> WidgetVitalsSnapshot {
        guard let defaults else { return .empty }

        if let data = defaults.data(forKey: WidgetSharedKeys.snapshot),
           let snapshot = try? JSONDecoder.widget.decode(WidgetVitalsSnapshot.self, from: data) {
            return snapshot
        }

        // Legacy fallback — only the scalar values written by DashboardView.
        var legacy = WidgetVitalsSnapshot.empty
        if defaults.object(forKey: WidgetSharedKeys.composite) != nil {
            legacy.compositeScore = defaults.integer(forKey: WidgetSharedKeys.composite)
        }
        legacy.pillarsActive = defaults.integer(forKey: WidgetSharedKeys.pillars)
        if let top = defaults.string(forKey: WidgetSharedKeys.topGoal) {
            legacy.topGoalTitle = top
        }
        legacy.topGoalStatus = defaults.string(forKey: WidgetSharedKeys.topStatus) ?? ""
        return legacy
    }

    /// Optimistically marks a task done in the stored snapshot so the widget
    /// reflects the tap before the app reconciles the real log. Best-effort: if
    /// decoding fails we leave the snapshot untouched.
    static func optimisticallyMarkTaskDone(taskID: UUID) {
        guard let defaults,
              let data = defaults.data(forKey: WidgetSharedKeys.snapshot),
              var snapshot = try? JSONDecoder.widget.decode(WidgetVitalsSnapshot.self, from: data)
        else { return }

        guard let index = snapshot.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        snapshot.tasks[index].isDone = true
        if let encoded = try? JSONEncoder.widget.encode(snapshot) {
            defaults.set(encoded, forKey: WidgetSharedKeys.snapshot)
        }
    }

    /// Appends a tap-to-log request to the App Group inbox for the app to drain.
    static func enqueueLogRequest(_ request: WidgetLogRequest) {
        guard let defaults else { return }
        var inbox: [WidgetLogRequest] = []
        if let data = defaults.data(forKey: WidgetSharedKeys.logInbox),
           let decoded = try? JSONDecoder.widget.decode([WidgetLogRequest].self, from: data) {
            inbox = decoded
        }
        inbox.append(request)
        if let encoded = try? JSONEncoder.widget.encode(inbox) {
            defaults.set(encoded, forKey: WidgetSharedKeys.logInbox)
        }
    }
}

extension JSONEncoder {
    /// Shared encoder so the app (writer) and widget (reader) agree on date
    /// representation. ISO-8601 keeps the JSON human-debuggable in the App Group.
    static var widget: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var widget: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
