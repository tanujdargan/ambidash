// ambidash/Services/IntegrationManager.swift
import Foundation
import SwiftData

@MainActor
@Observable
final class IntegrationManager {
    private let healthKit = HealthKitService.shared
    private let eventKit = EventKitService.shared
    private let notion = NotionService.shared
    private let obsidian = ObsidianService.shared
    private let screenTime = ScreenTimeService.shared

    var healthAuthorized = false
    var calendarAuthorized = false
    var remindersAuthorized = false
    var isLoading = false

    static var skipPermissions: Bool {
        CommandLine.arguments.contains("--skip-permissions") ||
        UserDefaults.standard.bool(forKey: "skip_permissions")
    }

    func requestAllPermissions() async {
        guard !Self.skipPermissions else { return }
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

        if notion.isConnected {
            let notionActivity = await notion.fetchRecentActivity()
            raw.notionPagesEditedToday = notionActivity.pagesEditedToday
        }

        if obsidian.isConnected {
            let obsidianActivity = await obsidian.fetchVaultActivity()
            raw.obsidianNotesModifiedToday = obsidianActivity.notesModifiedToday
        }

        if screenTime.isAuthorized {
            let screenData = await screenTime.fetchTodayScreenTime()
            raw.screenTimeHours = screenData.totalHours
            raw.screenCategories = screenData.categories
            raw.pickups = screenData.pickups
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
