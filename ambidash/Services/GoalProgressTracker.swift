import Foundation
import SwiftData

enum GoalProgressTracker {
    static func recordDaily(goal: Goal, context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let existing = goal.progressEntries.first {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
        guard existing == nil else { return }

        let score: Int
        switch goal.computedStatus {
        case .onTrack: score = 90
        case .needsAttention: score = 55
        case .slipping: score = 25
        case .paused: score = 0
        }

        let prior7 = goal.progressEntries
            .filter { $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: today)! }
            .map(\.score)
        let avg7 = prior7.isEmpty ? score : prior7.reduce(0, +) / prior7.count
        let trend = score - avg7

        let entry = GoalProgress(score: score, trend7d: trend, statusColor: goal.computedStatus)
        goal.progressEntries.append(entry)
    }

    static func recentScores(for goal: Goal, days: Int = 14) -> [Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return goal.progressEntries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map(\.score)
    }
}
