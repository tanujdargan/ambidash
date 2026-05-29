// ambidash/Services/NotificationService.swift
import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int = 21, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reflection"])

        let content = UNMutableNotificationContent()
        content.title = "Time to reflect"
        content.body = "How was your day? Take 2 minutes to log your progress."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-reflection", content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleMorningPlan(hour: Int = 7, minute: Int = 30) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning-plan"])

        let content = UNMutableNotificationContent()
        content.title = "Your day is ready"
        content.body = "Open ambidash to see today's plan."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.today.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "morning-plan", content: content, trigger: trigger)
        center.add(request)
    }

    /// Encouraging, progress-forward streak reminder. Celebrates the run so far and
    /// frames a single check-in today as keeping momentum — never as loss/punishment.
    /// `freezesRemaining`, when provided, reframes grace days as a built-in safety net
    /// rather than a weakness, so a single miss doesn't feel like a failure.
    static func scheduleStreakWarning(goalTitle: String, streakCount: Int, freezesRemaining: Int? = nil) {
        let center = UNUserNotificationCenter.current()
        let id = "streak-warning-\(goalTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Keep \(goalTitle) climbing"
        var body = "Your \(streakCount)-day streak for \(goalTitle) is strong — a quick check-in today keeps it climbing."
        if let freezesRemaining, freezesRemaining > 0 {
            let dayWord = freezesRemaining == 1 ? "day" : "days"
            body += " And don't worry — you've got \(freezesRemaining) grace \(dayWord) in reserve if life gets busy."
        }
        content.body = body
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.today.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    /// Supportive re-engagement nudge for a goal that's gone quiet. Frames the moment
    /// as a chance to reconnect and rebuild momentum rather than as backsliding.
    static func scheduleGoalDriftNudge(goalTitle: String, neglectDays: Int) {
        let center = UNUserNotificationCenter.current()
        let id = "drift-\(goalTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Reconnect with \(goalTitle)"
        content.body = "It's been \(neglectDays) days since you touched \(goalTitle). Time to reconnect and rebuild momentum — one small step today is enough."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.today.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    /// Honest, balanced check-in when a tracked metric has moved the wrong way.
    /// Acknowledges the change plainly without guilt and points toward a recovery action.
    static func scheduleLossFramingNudge(metric: String, currentValue: String, previousValue: String) {
        let center = UNUserNotificationCenter.current()
        let id = "loss-\(metric.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "A check-in on \(metric)"
        content.body = "Your \(metric.lowercased()) changed from \(previousValue) to \(currentValue). It happens — let's refocus tomorrow and steer it back."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = 14
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Longer-cadence review rituals (#14)

    /// Weekly review ritual reminder. `day` is a Calendar weekday (1 = Sunday ... 7 = Saturday);
    /// defaults to Monday. Repeats every week at the given time.
    static func scheduleWeeklyReview(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-review"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly review"
        content.body = "Take a few minutes to look back on your week and set your focus for the next one."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        // Clamp weekday into the valid 1...7 range so out-of-range input never drops the trigger.
        let weekday = min(max(day, 1), 7)
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "weekly-review", content: content, trigger: trigger)
        center.add(request)
    }

    /// Monthly review ritual reminder. `day` is a day-of-month (1...28 is always safe across
    /// every month; values are clamped to 28 to avoid skipping short months like February).
    /// Repeats every month at the given time.
    static func scheduleMonthlyReview(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["monthly-review"])

        let content = UNMutableNotificationContent()
        content.title = "Monthly review"
        content.body = "A new month is here. Reflect on your progress and recalibrate your goals."
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        // Clamp to 1...28 so the reminder fires every month (every month has a 28th).
        let dayOfMonth = min(max(day, 1), 28)
        var dateComponents = DateComponents()
        dateComponents.day = dayOfMonth
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "monthly-review", content: content, trigger: trigger)
        center.add(request)
    }

    /// Quarterly review ritual reminder anchored to a specific `month` (1...12) and `day` of that
    /// month. Repeats yearly for that anchor; schedule four anchors (one per quarter) to cover the
    /// full year. `day` is clamped to 1...28 to stay valid in every month.
    static func scheduleQuarterlyReview(month: Int, day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        // Clamp month into 1...12 and use it in the identifier so each quarter has a distinct request.
        let anchorMonth = min(max(month, 1), 12)
        let id = "quarterly-review-\(anchorMonth)"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Quarterly review"
        content.body = "Three months in — step back and take stock of the bigger picture. Where are you headed next?"
        content.sound = .default
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        let dayOfMonth = min(max(day, 1), 28)
        var dateComponents = DateComponents()
        dateComponents.month = anchorMonth
        dateComponents.day = dayOfMonth
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
