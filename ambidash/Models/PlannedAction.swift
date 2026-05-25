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

    var plan: DailyPlan?

    init(title: String, why: String = "", timeSlot: String = "", duration: Int = 30) {
        self.id = UUID()
        self.title = title
        self.whyReasoning = why
        self.timeSlot = timeSlot
        self.durationMinutes = duration
        self.statusRaw = "pending"
        self.completedAt = nil
        self.skipReason = nil
    }
}
