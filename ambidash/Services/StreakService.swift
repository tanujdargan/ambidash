// ambidash/Services/StreakService.swift
import Foundation

enum StreakService {
    struct StreakSummary {
        let totalActiveStreaks: Int
        let longestCurrentStreak: Int
        let atRiskStreaks: [(goalTitle: String, count: Int)]
    }

    static func summary(for goals: [Goal]) -> StreakSummary {
        var activeCount = 0
        var longest = 0
        var atRisk: [(String, Int)] = []

        for goal in goals where goal.isActive {
            guard let streak = goal.streak else { continue }
            if streak.currentCount > 0 && streak.isAlive {
                activeCount += 1
                longest = max(longest, streak.currentCount)

                if !Calendar.current.isDateInToday(streak.lastActiveDate) {
                    atRisk.append((goal.title, streak.currentCount))
                }
            }
        }

        return StreakSummary(
            totalActiveStreaks: activeCount,
            longestCurrentStreak: longest,
            atRiskStreaks: atRisk
        )
    }

    static func scheduleWarnings(for goals: [Goal]) {
        let atRisk = goals.filter { goal in
            guard let streak = goal.streak else { return false }
            return streak.currentCount > 0 && streak.isAlive && !Calendar.current.isDateInToday(streak.lastActiveDate)
        }

        for goal in atRisk {
            if let count = goal.streak?.currentCount {
                NotificationService.scheduleStreakWarning(goalTitle: goal.title, streakCount: count)
            }
        }
    }

    static func scheduleDriftNudges(for goals: [Goal]) {
        for goal in goals where goal.isActive && goal.neglectDays >= 5 {
            NotificationService.scheduleGoalDriftNudge(goalTitle: goal.title, neglectDays: goal.neglectDays)
        }
    }
}
