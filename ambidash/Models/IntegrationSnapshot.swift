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
