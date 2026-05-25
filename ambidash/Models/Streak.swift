import Foundation
import SwiftData

@Model
final class Streak {
    var id: UUID
    var currentCount: Int
    var bestCount: Int
    var lastActiveDate: Date

    var goal: Goal?

    init() {
        self.id = UUID()
        self.currentCount = 0
        self.bestCount = 0
        self.lastActiveDate = .now
    }

    var isAlive: Bool {
        Calendar.current.isDateInToday(lastActiveDate) ||
        Calendar.current.isDateInYesterday(lastActiveDate)
    }

    func recordActivity() {
        if Calendar.current.isDateInToday(lastActiveDate) { return }
        if Calendar.current.isDateInYesterday(lastActiveDate) {
            currentCount += 1
        } else {
            currentCount = 1
        }
        if currentCount > bestCount {
            bestCount = currentCount
        }
        lastActiveDate = .now
    }
}
