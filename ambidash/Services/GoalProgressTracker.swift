import Foundation
import SwiftData

enum GoalProgressTracker {
    static func recordDaily(goal: Goal, context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let existing = (goal.progressEntries ?? []).first {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
        guard existing == nil else { return }

        let score: Int
        let statusColor: GoalStatus
        if goal.hasTarget {
            // F2 — measurable goals scored by pace toward target.
            score = Int((goal.percentComplete * 100).rounded())
            switch TargetMath.variance(goal) {
            case .ahead: statusColor = .onTrack
            case .onTrack: statusColor = .needsAttention
            case .behind: statusColor = .slipping
            }
        } else if goal.isActive && goal.isHabitual {
            // F3 — habitual goals scored by weekly cadence adherence, not pure
            // days-since-last-touch, so a Mon/Wed/Fri lifter reads on-track Tuesday.
            let adherence = goal.adherenceThisWeek
            score = Int((adherence * 100).rounded())
            if adherence >= 1.0 {
                statusColor = .onTrack
            } else if adherence >= 0.5 {
                statusColor = .needsAttention
            } else {
                statusColor = .slipping
            }
        } else {
            // Non-habitual, non-target goals keep the neglect-based recency scoring.
            switch goal.computedStatus {
            case .onTrack: score = 90
            case .needsAttention: score = 55
            case .slipping: score = 25
            case .paused: score = 0
            }
            statusColor = goal.computedStatus
        }

        let prior7 = (goal.progressEntries ?? [])
            .filter { $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: today)! }
            .map(\.score)
        let avg7 = prior7.isEmpty ? score : prior7.reduce(0, +) / prior7.count
        let trend = score - avg7

        let entry = GoalProgress(score: score, trend7d: trend, statusColor: statusColor)
        context.insert(entry)
        entry.goal = goal
    }

    static func recentScores(for goal: Goal, days: Int = 14) -> [Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return (goal.progressEntries ?? [])
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map(\.score)
    }
}
