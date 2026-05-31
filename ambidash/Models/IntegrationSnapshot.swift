import Foundation
import SwiftData

@Model
final class IntegrationSnapshot {
    var id: UUID = UUID()
    var date: Date = Date()
    var sleepHours: Double = 0
    var sleepScore: Int = 0
    var steps: Int = 0
    var workoutCount: Int = 0
    var screenTimeHours: Double = 0
    var screenCategories: [String: Double] = [:]
    var pickups: Int = 0
    var calendarFreeMinutes: Int = 0
    var notionPagesEditedToday: Int = 0
    var obsidianNotesModifiedToday: Int = 0

    // MARK: - LEARNING augmentation (build-order #3 — from logged actuals)
    // All additive/defaulted (CloudKit-safe). Sourced from LearningService over the
    // day's ActualEvents/EnergyCheckins so the snapshot reflects how the user ACTUALLY
    // lived, not just device sensors. -1 sentinels mean "no signal yet" (graceful).

    /// Real inferred wake time, minutes-from-midnight (-1 = unknown). From the
    /// earliest logged actual / HealthKit, not the aspirational preference.
    var realWakeMinutes: Int = -1
    /// Real inferred sleep/wind-down time, minutes-from-midnight (-1 = unknown).
    var realSleepMinutes: Int = -1
    /// Overall completion adherence for the day, 0…1 (-1 = no logged events). The
    /// fraction of logged blocks that resolved as completed. NON-PUNITIVE: a HINT for
    /// the planner, surfaced with sample size, never a grade.
    var adherenceScore: Double = -1
    /// Energy balance for the day, -1…1 (-2 = no signal): planned/expected energy
    /// spend vs. reported energy. Positive = room to spare, negative = overspent.
    /// Informational only; never blocks planning.
    var energyBalance: Double = -2

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.sleepHours = 0
        self.sleepScore = 0
        self.steps = 0
        self.workoutCount = 0
        self.screenTimeHours = 0
        self.screenCategories = [:]
        self.pickups = 0
        self.calendarFreeMinutes = 0
        self.notionPagesEditedToday = 0
        self.obsidianNotesModifiedToday = 0
        self.realWakeMinutes = -1
        self.realSleepMinutes = -1
        self.adherenceScore = -1
        self.energyBalance = -2
    }
}
