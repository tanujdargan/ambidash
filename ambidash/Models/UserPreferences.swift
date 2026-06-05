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

    // v4 wake-adjust workflow: the actual wake time (minute-of-day) detected the
    // first time the app was opened today, vs the `wakeTime` target above. When the
    // two drift apart the app gently offers to re-adjust the goal or the wind-down.
    // CloudKit-additive (defaulted scalar + optional date, no migration).
    var lastActualWakeMinutes: Int = -1   // -1 = not recorded yet
    var lastWakeRecordDay: Date? = nil
    // Multi-week wake drift: rolling 7-day history of actual wake minutes (newest first).
    var recentWakeMinutes: [Int] = []

    // "I'm unwell" recovery mode: lightens the day and shows a recovery banner.
    var isUnwellMode: Bool = false
    var unwellSince: Date?

    // v5 DAY ALARMS — dedicated recurring wake/bedtime alarms, distinct from the per-block
    // timeline alarms (AlarmService). Additive/defaulted (CloudKit-safe) and OFF by default
    // so nothing changes for existing users until they opt in. When enabled, AlarmService
    // schedules a genuine recurring alarm/reminder at `wakeTime`/`sleepTime`:
    //  • wake defaults to an unmissable `alarm` (AlarmKit on iOS 26; time-sensitive reminder
    //    fallback) — a wake-up you can't sleep through is the whole point.
    //  • bedtime defaults to a `gentle` wind-down nudge — a calm invitation, not a buzz.
    // Mode is stored as a PlannedAction.AlarmMode raw string (`off`/`gentle`/`alarm`) so the
    // existing typed accessor + scheduling path are reused. `syncWakeAlarmToPlan` makes the
    // wake alarm follow the day's actual first scheduled block when a plan exists, so the
    // alarm and the plan never drift apart.
    var wakeAlarmEnabled: Bool = false
    var bedtimeAlarmEnabled: Bool = false
    var wakeAlarmModeRaw: String = "alarm"
    var bedtimeAlarmModeRaw: String = "gentle"
    var syncWakeAlarmToPlan: Bool = true

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

    // ENERGY budgeting (design principle #6). Additive/defaulted (CloudKit-safe).
    // OFF by default so nothing changes for existing users; when on, the planner may
    // flag (never block) days whose estimated spend exceeds the budget. Aspirational,
    // never enforced. `dailyEnergyBudget` is in abstract "spoons" (1 unit ≈ one
    // medium-effort block); the default is a gentle starting point, fully editable.
    var enableEnergyBudgeting: Bool = false
    var dailyEnergyBudget: Int = 12

    // FOCUS SESSION soundscape (additive/defaulted, CloudKit-safe). OFF by default so
    // nothing changes for existing users and no audio session is ever touched unless
    // the user opts in. When on, the focus timer loops a quiet ambient sound via
    // AVAudioSession .ambient (mixes with the user's music, respects the silent
    // switch). A safe no-op if no sound asset is bundled.
    var focusSoundEnabled: Bool = false

    // TRANSITION BUFFERS (display-time only, additive/defaulted). When on, the timeline
    // inserts gentle, non-interactive "wrap up → next" markers between consecutive
    // blocks that sit close together, sized small in the muted/deferred token. Purely a
    // render-time concern — no persisted model, no CloudKit/plan impact. Defaults ON;
    // only ever shown when a gap is genuinely tight, so calm days stay uncluttered.
    var showTransitionBuffers: Bool = true

    // "TODAY IS HARD" MODE (additive/defaulted, CloudKit-safe). A per-DAY flag, NOT a
    // global bool: stores the start-of-day (as a stored `Date?`) of the day the user
    // marked hard. Compared with `Calendar.isDateInToday` so it auto-expires when the
    // day rolls over — no migration, no new @Model. When today is marked hard the board
    // softens to a minimal, kind set ("today, just one thing" + rest option) and copy
    // gentles app-wide for the day. Fully reversible (set back to nil). nil = not hard.
    var hardModeDay: Date? = nil

    // REST-DAY BANK (additive/defaulted, CloudKit-safe). Guilt-free rest days the user
    // EARNS through consistency and SPENDS with no penalty (streak-safe, non-punitive).
    // `bankedRestDays` is the current balance; the earned/spent totals are kept purely
    // for a warm "X earned · Y spent" breakdown and never gate anything. All scalars on
    // the already-registered UserPreferences → nothing new to register in either
    // ModelContainer. Defaults to 0 so existing users start with an empty, growing bank.
    var bankedRestDays: Int = 0
    var restDaysEarnedTotal: Int = 0
    var restDaysSpentTotal: Int = 0
    // The start-of-day (stored `Date?`) of the last day a banked rest day was spent, so
    // spending is idempotent per day (you can't drain the bank by re-tapping). nil =
    // never spent / not spent today.
    var lastRestDaySpent: Date? = nil
    // The start-of-day (stored `Date?`) of the last consistency check that granted (or
    // evaluated) an earned rest day, so earning is evaluated at most once per day and
    // never double-credits. nil = never evaluated.
    var lastRestEarnCheck: Date? = nil

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
