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

    init(title: String, why: String = "", timeSlot: String = "", duration: Int = 30, goalID: UUID? = nil, goalTitleSnapshot: String? = nil, loggedAmount: Double? = nil) {
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
    }
}
