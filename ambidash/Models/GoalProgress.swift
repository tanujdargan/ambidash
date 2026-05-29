import Foundation
import SwiftData

@Model
final class GoalProgress {
    var id: UUID = UUID()
    var date: Date = Date()
    var score: Int = 0
    var trend7d: Int = 0
    var statusColorRaw: String = GoalStatus.onTrack.rawValue

    var goal: Goal?

    init(score: Int, trend7d: Int = 0, statusColor: GoalStatus = .onTrack) {
        self.id = UUID()
        self.date = .now
        self.score = score
        self.trend7d = trend7d
        self.statusColorRaw = statusColor.rawValue
    }
}
