import Foundation
import SwiftData

@Model
final class IntegrationSnapshot {
    var id: UUID
    var date: Date
    var sleepHours: Double
    var sleepScore: Int
    var steps: Int
    var workoutCount: Int
    var screenTimeHours: Double
    var screenCategories: [String: Double]
    var pickups: Int
    var calendarFreeMinutes: Int
    var notionPagesEditedToday: Int
    var obsidianNotesModifiedToday: Int

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
    }
}
