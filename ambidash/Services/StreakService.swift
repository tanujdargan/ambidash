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

    // MARK: - Notification scheduling (iOS-only)
    // These wrap UserNotifications via NotificationService, which is iOS-only and
    // excluded from the macOS target. The function signatures stay so any shared
    // call site compiles; the bodies are no-ops on macOS.

    static func scheduleWarnings(for goals: [Goal]) {
        #if os(iOS)
        let atRisk = goals.filter { goal in
            guard let streak = goal.streak else { return false }
            return streak.currentCount > 0 && streak.isAlive && !Calendar.current.isDateInToday(streak.lastActiveDate)
        }

        for goal in atRisk {
            if let streak = goal.streak {
                // Pass the remaining grace days so the nudge can frame freezes as a
                // safety net, keeping the reminder supportive rather than punitive.
                NotificationService.scheduleStreakWarning(
                    goalTitle: goal.title,
                    streakCount: streak.currentCount,
                    freezesRemaining: streak.freezesRemaining
                )
            }
        }
        #endif
    }

    static func scheduleDriftNudges(for goals: [Goal]) {
        #if os(iOS)
        for goal in goals where goal.isActive && goal.neglectDays >= 5 {
            NotificationService.scheduleGoalDriftNudge(goalTitle: goal.title, neglectDays: goal.neglectDays)
        }
        #endif
    }

    // MARK: - Longer-cadence review ritual reminders (#14)

    /// Schedules the recurring weekly review reminder (defaults to Monday at 10:00).
    static func scheduleWeeklyReviewReminder(day: Int = 2, hour: Int = 10, minute: Int = 0) {
        #if os(iOS)
        NotificationService.scheduleWeeklyReview(day: day, hour: hour, minute: minute)
        #endif
    }

    /// Schedules the recurring monthly review reminder (defaults to the 1st at 10:00).
    static func scheduleMonthlyReviewReminder(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        #if os(iOS)
        NotificationService.scheduleMonthlyReview(day: day, hour: hour, minute: minute)
        #endif
    }

    /// Schedules quarterly review reminders for all four quarters. Anchors to the 1st of
    /// Jan/Apr/Jul/Oct by default so each quarter gets its own recurring reminder.
    static func scheduleQuarterlyReviewReminder(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        #if os(iOS)
        for month in [1, 4, 7, 10] {
            NotificationService.scheduleQuarterlyReview(month: month, day: day, hour: hour, minute: minute)
        }
        #endif
    }
}
