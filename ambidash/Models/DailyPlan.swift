import Foundation
import SwiftData

@Model
final class DailyPlan {
    var id: UUID = UUID()
    var date: Date = Date()
    var formatRaw: String = ""
    var actionCount: Int = 0
    var regenerated: Bool = false
    var generatedAt: Date = Date()

    @Relationship(deleteRule: .cascade) var actions: [PlannedAction]?

    init(date: Date = .now, format: PlanFormat = .focusBlocks) {
        self.id = UUID()
        self.date = date
        self.formatRaw = format.rawValue
        self.actionCount = 0
        self.regenerated = false
        self.generatedAt = .now
    }
}
