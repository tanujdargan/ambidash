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

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "morning-plan", content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleStreakWarning(goalTitle: String, streakCount: Int) {
        let center = UNUserNotificationCenter.current()
        let id = "streak-warning-\(goalTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Streak at risk"
        content.body = "Your \(streakCount)-day streak for \(goalTitle) ends at midnight. Don't lose it."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleGoalDriftNudge(goalTitle: String, neglectDays: Int) {
        let center = UNUserNotificationCenter.current()
        let id = "drift-\(goalTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "\(goalTitle) is slipping"
        content.body = "You haven't made progress on \(goalTitle) in \(neglectDays) days. At this rate, you're moving backwards."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleLossFramingNudge(metric: String, currentValue: String, previousValue: String) {
        let center = UNUserNotificationCenter.current()
        let id = "loss-\(metric.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "\(metric) is getting worse"
        content.body = "Your \(metric.lowercased()) went from \(previousValue) to \(currentValue). You're undoing progress."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 14
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
