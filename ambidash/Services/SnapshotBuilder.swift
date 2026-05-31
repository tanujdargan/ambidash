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

    /// LEARNING augmentation (build-order #3) — fold a `LearnedProfile` (computed by
    /// `LearningService` from the day's logged actuals/energy) into a snapshot's real
    /// wake/sleep + adherence + energy-balance fields. Additive and optional: callers
    /// that don't have a profile yet simply don't call this and the fields keep their
    /// "no signal" sentinels. Pure; the caller owns the save.
    static func augment(_ snapshot: IntegrationSnapshot, with learned: LearnedProfile) {
        if let wake = learned.realWakeMinutes { snapshot.realWakeMinutes = wake }
        if let sleep = learned.realSleepMinutes { snapshot.realSleepMinutes = sleep }

        // Day-wide adherence = completed / total across every hour that has logged
        // events. -1 stays when there's nothing logged (never read as 0 = "failed").
        let buckets = learned.adherenceByHour.values
        let total = buckets.reduce(0) { $0 + $1.total }
        if total > 0 {
            let completed = buckets.reduce(0) { $0 + $1.completed }
            snapshot.adherenceScore = Double(completed) / Double(total)
        }

        // Energy balance: average reported energy mapped to roughly -1…1 around the
        // mid-point (3 of 5). Positive = energy to spare, negative = running low.
        // Informational only — never blocks planning. -2 stays with no readings.
        let energies = learned.energyByHour.values
        if !energies.isEmpty {
            let avg = energies.reduce(0, +) / Double(energies.count)
            snapshot.energyBalance = max(-1, min(1, (avg - 3) / 2))
        }
    }

    private static func computeSleepScore(hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours >= 9 { return 85 }
        if hours >= 7 { return Int(80 + (hours - 7) * 5) }
        if hours >= 6 { return Int(50 + (hours - 6) * 30) }
        return max(Int(hours / 6 * 50), 5)
    }
}
