import Foundation
import SwiftData

@Model
final class GoalProgress {
    var id: UUID
    var date: Date
    var score: Int
    var trend7d: Int
    var statusColorRaw: String

    var goal: Goal?

    init(score: Int, trend7d: Int = 0, statusColor: GoalStatus = .onTrack) {
        self.id = UUID()
        self.date = .now
        self.score = score
        self.trend7d = trend7d
        self.statusColorRaw = statusColor.rawValue
    }
}
