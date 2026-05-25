import Foundation
import SwiftData

@Model
final class DailyPlan {
    var id: UUID
    var date: Date
    var formatRaw: String
    var actionCount: Int
    var regenerated: Bool
    var generatedAt: Date

    @Relationship(deleteRule: .cascade) var actions: [PlannedAction]

    init(date: Date = .now, format: PlanFormat = .focusBlocks) {
        self.id = UUID()
        self.date = date
        self.formatRaw = format.rawValue
        self.actionCount = 0
        self.regenerated = false
        self.generatedAt = .now
        self.actions = []
    }
}
