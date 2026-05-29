import AppIntents
import WidgetKit

/// Interactive tap-to-log button hosted inside the widget. Tapping it:
///   1. optimistically marks the task done in the shared snapshot (instant UI),
///   2. enqueues a `WidgetLogRequest` into the App Group inbox, and
///   3. reloads the widget timelines so the change is reflected immediately.
///
/// The actual SwiftData ProgressLog/Streak write is performed by the app when
/// it next foregrounds and drains the inbox — the widget extension can't open
/// the app's CloudKit-backed SwiftData container, so persistence is deferred
/// rather than attempted (and silently failing) here.
struct LogTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Task"
    static let description = IntentDescription("Mark a goal task done from the widget.")
    static let isDiscoverable = false

    @Parameter(title: "Task ID")
    var taskID: String

    @Parameter(title: "Goal ID")
    var goalID: String

    init() {}

    init(taskID: UUID, goalID: UUID?) {
        self.taskID = taskID.uuidString
        self.goalID = goalID?.uuidString ?? ""
    }

    func perform() async throws -> some IntentResult {
        if let task = UUID(uuidString: taskID) {
            WidgetSharedStore.optimisticallyMarkTaskDone(taskID: task)
            WidgetSharedStore.enqueueLogRequest(
                WidgetLogRequest(
                    id: UUID(),
                    goalID: UUID(uuidString: goalID),
                    taskID: task,
                    requestedAt: .now
                )
            )
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
