// ambidash/Services/SnapshotBuilder.swift
import Foundation

enum SnapshotBuilder {
    struct RawData {
        var sleepHours: Double = 0
        var steps: Int = 0
        var workoutCount: Int = 0
        var restingHeartRate: Double = 0
        var calendarFreeMinutes: Int = 0
        var overdueReminders: Int = 0
        var screenTimeHours: Double = 0
        var screenCategories: [String: Double] = [:]
        var pickups: Int = 0
        var notionPagesEditedToday: Int = 0
        var obsidianNotesModifiedToday: Int = 0
    }

    static func build(from raw: RawData, for date: Date) -> IntegrationSnapshot {
        let snapshot = IntegrationSnapshot(date: date)
        apply(raw, to: snapshot)
        return snapshot
    }

    static func update(_ snapshot: IntegrationSnapshot, with raw: RawData) {
        apply(raw, to: snapshot)
    }

    private static func apply(_ raw: RawData, to snapshot: IntegrationSnapshot) {
        snapshot.sleepHours = raw.sleepHours
        snapshot.sleepScore = computeSleepScore(hours: raw.sleepHours)
        snapshot.steps = raw.steps
        snapshot.workoutCount = raw.workoutCount
        snapshot.calendarFreeMinutes = raw.calendarFreeMinutes
        snapshot.screenTimeHours = raw.screenTimeHours
        snapshot.screenCategories = raw.screenCategories
        snapshot.pickups = raw.pickups
        snapshot.notionPagesEditedToday = raw.notionPagesEditedToday
        snapshot.obsidianNotesModifiedToday = raw.obsidianNotesModifiedToday
    }

    private static func computeSleepScore(hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours >= 9 { return 85 }
        if hours >= 7 { return Int(80 + (hours - 7) * 5) }
        if hours >= 6 { return Int(50 + (hours - 6) * 30) }
        return max(Int(hours / 6 * 50), 5)
    }
}
