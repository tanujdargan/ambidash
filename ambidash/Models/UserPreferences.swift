import Foundation
import SwiftData

/// FOUNDATION — the user's daily life rhythm. Grounds AI + offline plan
/// generation in realistic constraints (wake/sleep, meals, work blocks,
/// routines, exercise) so the day is built around how the user actually lives
/// rather than free-floating goal nags.
///
/// CloudKit-safe: every scalar carries a default and the relationship back to
/// UserProfile is optional. Defaults reflect a sensible ideal day (early riser,
/// morning routine, evening workout, self-cooked dinner, meals on time) but are
/// presented to the user as editable starting points, NOT facts.
@Model
final class UserPreferences {
    var id: UUID = UUID()

    // Day boundaries (HH:mm clock strings — simple, human-editable, prompt-ready).
    var wakeTime: String = "07:00"
    var sleepTime: String = "23:30"

    // Meal anchors.
    var breakfastTime: String = "08:00"
    var lunchTime: String = "13:00"
    var dinnerTime: String = "19:00"

    // Work / class busy block (free text so it can describe split or variable days).
    var workBusyBlock: String = "09:00–17:00 class or work"

    // Daily routines (free text / loose lists).
    var morningRoutine: String = "skincare, oral care, no phone first 30 min, coffee"
    var eveningRoutine: String = "reflection, light reading, no screens after 22:00"

    // Exercise.
    var worksOut: Bool = true
    var workoutTime: String = "18:00"
    var workoutType: String = "gym session"

    // Meals.
    var cooksOwnMeals: Bool = true

    // Energy + focus patterns.
    var energyPeak: String = "morning"   // morning | afternoon | evening
    var focusBlocksPerDay: Int = 3

    // Free-form context the planner should weave in.
    var aboutMe: String = ""
    var hardConstraints: String = ""
    var extraContext: String = ""

    // Explicit inverse so the one-to-one UserProfile.userPreferences <->
    // UserPreferences.profile pairing is unambiguous to SwiftData/CloudKit.
    // Declared on this (child) side only, matching the codebase convention; kept
    // optional + additive so existing data is untouched.
    @Relationship(inverse: \UserProfile.userPreferences) var profile: UserProfile?

    init() {
        self.id = UUID()
        // All defaults are set in the property declarations above.
    }
}
