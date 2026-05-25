// ambidash/Services/IntegrationManager.swift
import Foundation
import SwiftData

@MainActor
@Observable
final class IntegrationManager {
    private let healthKit = HealthKitService.shared
    private let eventKit = EventKitService.shared

    var healthAuthorized = false
    var calendarAuthorized = false
    var remindersAuthorized = false
    var isLoading = false

    func requestAllPermissions() async {
        async let health = healthKit.requestAuthorization()
        async let calendar = eventKit.requestCalendarAccess()
        async let reminders = eventKit.requestRemindersAccess()

        healthAuthorized = await health
        calendarAuthorized = await calendar
        remindersAuthorized = await reminders
    }

    func refreshTodaySnapshot(in context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        let today = Date.now

        var raw = SnapshotBuilder.RawData()

        if healthAuthorized {
            async let sleep = healthKit.fetchSleepHours(for: today)
            async let steps = healthKit.fetchSteps(for: today)
            async let workouts = healthKit.fetchWorkoutCount(for: today)
            async let hr = healthKit.fetchRestingHeartRate(for: today)

            raw.sleepHours = await sleep
            raw.steps = await steps
            raw.workoutCount = await workouts
            raw.restingHeartRate = await hr
        }

        if calendarAuthorized {
            raw.calendarFreeMinutes = await eventKit.computeFreeMinutes(for: today)
        }

        if remindersAuthorized {
            raw.overdueReminders = await eventKit.fetchOverdueReminderCount()
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)

        let descriptor = FetchDescriptor<IntegrationSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.date >= startOfDay
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            SnapshotBuilder.update(existing, with: raw)
        } else {
            let snapshot = SnapshotBuilder.build(from: raw, for: today)
            context.insert(snapshot)
        }

        try? context.save()
    }
}
