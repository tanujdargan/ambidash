import Foundation
import SwiftData

@Model
final class PlannedAction {
    var id: UUID
    var title: String
    var whyReasoning: String
    var timeSlot: String
    var durationMinutes: Int
    var statusRaw: String
    var completedAt: Date?
    var skipReason: String?
    var goalID: UUID?
    var goalTitleSnapshot: String?
    /// Measurable increment (in the goal's unit) this action should add to its
    /// goal's currentValue when completed. nil for goals without a target.
    var loggedAmount: Double?

    var plan: DailyPlan?
    /// C1 — the Milestone (week/month node) this daily action advances, if any.
    /// Optional/defaulted: goal lineage still flows through the `goalID` scalar;
    /// this adds traceability to the checkpoint the action chips away at.
    var milestone: Milestone? = nil

    init(title: String, why: String = "", timeSlot: String = "", duration: Int = 30, goalID: UUID? = nil, goalTitleSnapshot: String? = nil, loggedAmount: Double? = nil, milestone: Milestone? = nil) {
        self.id = UUID()
        self.title = title
        self.whyReasoning = why
        self.timeSlot = timeSlot
        self.durationMinutes = duration
        self.statusRaw = "pending"
        self.completedAt = nil
        self.skipReason = nil
        self.goalID = goalID
        self.goalTitleSnapshot = goalTitleSnapshot
        self.loggedAmount = loggedAmount
        self.milestone = milestone
    }
}
