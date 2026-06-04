// ambidash/Services/NotificationService+Smart.swift
//
// v5 feat/v5-notifications — the smart notification LAYER over NotificationService. Adds:
//  • three adaptive daily check-ins (morning energy / midday progress / evening reflection),
//  • learned-optimal goal nudges (best energy+adherence hour, dodging calendar-busy spans),
//  • streak-at-risk reminders at the adaptive evening time,
// all delivered as GROUPED notifications via `threadIdentifier` so Notification Center collapses
// each kind into one stack instead of a wall of separate alerts. Timing decisions come from the
// pure SmartNotificationPlanner; this file is the (iOS-only) scheduling glue.
import Foundation
#if os(iOS)
import UserNotifications
import SwiftData

extension NotificationService {

    /// Notification Center group threads — related notifications collapse under one stack.
    enum Group {
        static let checkIns = "ambidash.group.checkins"
        static let goalNudges = "ambidash.group.goalnudges"
        static let streaks = "ambidash.group.streaks"
    }

    // MARK: - Daily check-ins

    /// Schedule the three adaptive daily check-ins as repeating notifications grouped under one
    /// thread. Times adapt to the user's waking window. Idempotent on fixed ids.
    static func scheduleDailyCheckIns(wakeMinutes: Int, sleepMinutes: Int) {
        let times = SmartNotificationPlanner.checkInTimes(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
        scheduleCheckIn(id: "checkin.morning", minute: times.morning,
                        title: "Morning check-in", body: "How's your energy today? A quick tap logs it.",
                        deepLink: DeepLink.today)
        scheduleCheckIn(id: "checkin.midday", minute: times.midday,
                        title: "Midday check-in", body: "How's it going so far? A glance keeps you on track.",
                        deepLink: DeepLink.today)
        scheduleCheckIn(id: "checkin.evening", minute: times.evening,
                        title: "Evening reflection", body: "Take a breath — what went well today?",
                        deepLink: DeepLink.reflect)
    }

    /// Cancel the three daily check-ins.
    static func cancelDailyCheckIns() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["checkin.morning", "checkin.midday", "checkin.evening"]
        )
    }

    private static func scheduleCheckIn(id: String, minute: Int, title: String, body: String, deepLink: DeepLink) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let (h, m) = clampToWaking(hour: minute / 60, minute: minute % 60)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .passive
        content.threadIdentifier = Group.checkIns
        content.userInfo = ["deepLink": deepLink.rawValue]

        var dc = DateComponents(); dc.hour = h; dc.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Smart goal nudge

    /// A daily nudge for one goal at its learned-optimal minute, grouped under the goal-nudges
    /// thread. Repeats daily at that time (recomputed each refresh as patterns evolve).
    static func scheduleSmartGoalNudge(goalID: UUID, goalTitle: String, atMinute minute: Int) {
        let center = UNUserNotificationCenter.current()
        let id = "smartnudge.\(goalID.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let (h, m) = clampToWaking(hour: minute / 60, minute: minute % 60)

        let content = UNMutableNotificationContent()
        content.title = goalTitle
        content.body = "A good moment to move this forward — even a little counts."
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = Group.goalNudges
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "goalID": goalID.uuidString]

        var dc = DateComponents(); dc.hour = h; dc.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancelSmartGoalNudge(goalID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["smartnudge.\(goalID.uuidString)"]
        )
    }

    // MARK: - Streak at-risk

    /// A supportive streak-at-risk reminder at the adaptive evening time, grouped under the
    /// streaks thread. Fires once at the next occurrence of that time (today, if still ahead).
    static func scheduleAtRiskStreakReminder(index: Int, goalTitle: String, streakCount: Int, atMinute minute: Int) {
        guard streakCount > 0 else { return }
        let center = UNUserNotificationCenter.current()
        let id = "atrisk.\(index)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let (h, m) = clampToWaking(hour: minute / 60, minute: minute % 60)

        let content = UNMutableNotificationContent()
        content.title = "Keep your \(streakCount)-day streak"
        content.body = "\(goalTitle): a tiny bit today keeps the run alive. No pressure — you've got this."
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = Group.streaks
        content.userInfo = ["deepLink": DeepLink.today.rawValue]

        var dc = DateComponents(); dc.hour = h; dc.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Ties the learned profile + today's calendar + streaks together into one scheduling pass. Call
/// from the app's notification-scheduling seam (DashboardView's `.task`).
@MainActor
enum SmartNotificationCoordinator {

    /// Reconcile all smart notifications. `busy` are today's calendar-busy spans (minute-of-day),
    /// usually derived from EventKitService; pass `[]` when calendar access is off.
    static func refresh(
        context: ModelContext,
        wakeMinutes: Int,
        sleepMinutes: Int,
        goals: [Goal],
        busy: [SmartNotificationPlanner.BusyInterval]
    ) {
        // 1. Adaptive daily check-ins.
        NotificationService.scheduleDailyCheckIns(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)

        // 2. Learned-optimal nudge for the most-neglected active goal, dodging calendar-busy spans.
        let profile = LearningService.buildProfile(from: context)
        let adherence = profile.adherenceByHour.mapValues(\.ratio)
        let nudgeMinute = SmartNotificationPlanner.optimalNudgeMinute(
            energyByHour: profile.energyByHour,
            adherenceByHour: adherence,
            wakeMinutes: wakeMinutes,
            sleepMinutes: sleepMinutes,
            busy: busy
        )
        let active = goals.filter(\.isActive)
        if let goal = active.max(by: { $0.neglectDays < $1.neglectDays }) {
            NotificationService.scheduleSmartGoalNudge(goalID: goal.id, goalTitle: goal.title, atMinute: nudgeMinute)
        }

        // 3. Streak-at-risk reminders at the adaptive evening time.
        let times = SmartNotificationPlanner.checkInTimes(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
        let atRisk = StreakService.summary(for: goals).atRiskStreaks
        // Clear stale slots first (up to a small cap), then schedule current ones.
        for i in 0..<5 {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["atrisk.\(i)"])
        }
        for (i, risk) in atRisk.prefix(3).enumerated() {
            NotificationService.scheduleAtRiskStreakReminder(
                index: i, goalTitle: risk.goalTitle, streakCount: risk.count, atMinute: times.evening
            )
        }
    }
}
#endif
