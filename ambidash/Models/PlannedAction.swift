import Foundation
import SwiftData

@Model
final class PlannedAction {
    var id: UUID = UUID()
    var title: String = ""
    var whyReasoning: String = ""
    var timeSlot: String = ""
    var durationMinutes: Int = 0
    var statusRaw: String = "pending"
    var completedAt: Date?
    var skipReason: String?
    var goalID: UUID?
    var goalTitleSnapshot: String?
    /// Measurable increment (in the goal's unit) this action should add to its
    /// goal's currentValue when completed. nil for goals without a target.
    var loggedAmount: Double?

    var plan: DailyPlan?
    /// C1 — the Milestone (week/month node) this daily action advances, if any.
    /// Optional/defaulted: goal lineage still flows through the `goalID` scalar;
    /// this adds traceability to the checkpoint the action chips away at.
    var milestone: Milestone? = nil

    /// C2 — the date of the prior DailyPlan this action was carried forward from,
    /// when it resurfaced as unfinished work. nil for freshly generated/added
    /// actions. Doubles as the idempotency marker so CarryOverService never
    /// double-clones the same prior action into one day's plan.
    /// Optional/defaulted (additive, CloudKit-safe).
    var carriedOverFrom: Date? = nil

    /// A2 / #10 — the if-then implementation-intention anchor for this action,
    /// e.g. "after breakfast" or "when I sit down at my desk". Empty when the
    /// planner produced no cue. Defaulted (additive, CloudKit-safe).
    var cueTrigger: String = ""

    /// A2 / #10 — the quantitative target this action is sized to (reps / minutes /
    /// pages / etc.), surfaced to the user so the action is concrete rather than
    /// vague. nil when the goal isn't measurable/quantifiable. Distinct from
    /// `loggedAmount`, which is the increment credited to a measurable goal's
    /// currentValue: targetAmount/targetUnit are display-facing intent that may
    /// also apply to habitual goals (e.g. "20 reps") where nothing is logged.
    /// Optional/defaulted (additive, CloudKit-safe).
    var targetAmount: Double? = nil

    /// A2 / #10 — the unit for `targetAmount` (e.g. "reps", "min", "pages").
    /// Empty when there is no quantitative target. Defaulted (CloudKit-safe).
    var targetUnit: String = ""

    /// PLAN REWRITE — what KIND of timeline entry this is:
    /// - "fixed"     → a fixed daily anchor (wake, a meal, sleep, a work/class block)
    /// - "routine"   → a recurring daily routine pulled from the user's preferences
    ///                 (morning routine, workout, cook dinner)
    /// - "goal_work" → concrete work toward an active goal, slotted into a free gap
    /// The day is woven from all three. Defaults to "goal_work" so every
    /// pre-existing action keeps its meaning. Additive/defaulted (CloudKit-safe).
    var anchorType: String = "goal_work"

    /// PLAN REWRITE — the human-facing relative time cue when an action isn't
    /// pinned to a single clock time, e.g. "Before 13:00", "After class".
    /// `timeSlot` remains the sortable HH:MM scheduling key; `scheduleCue` is the
    /// instruction-style label the timeline shows when present. Empty falls back
    /// to `timeSlot`. Additive/defaulted (CloudKit-safe).
    var scheduleCue: String = ""

    init(title: String, why: String = "", timeSlot: String = "", duration: Int = 30, goalID: UUID? = nil, goalTitleSnapshot: String? = nil, loggedAmount: Double? = nil, milestone: Milestone? = nil, carriedOverFrom: Date? = nil, cueTrigger: String = "", targetAmount: Double? = nil, targetUnit: String = "", anchorType: String = "goal_work", scheduleCue: String = "") {
        self.id = UUID()
        self.title = title
        self.whyReasoning = why
        self.timeSlot = timeSlot
        self.durationMinutes = duration
        self.statusRaw = "pending"
        self.completedAt = nil
        self.skipReason = nil
        self.goalID = goalID
        self.goalTitleSnapshot = goalTitleSnapshot
        self.loggedAmount = loggedAmount
        self.milestone = milestone
        self.carriedOverFrom = carriedOverFrom
        self.cueTrigger = cueTrigger
        self.targetAmount = targetAmount
        self.targetUnit = targetUnit
        self.anchorType = anchorType
        self.scheduleCue = scheduleCue
    }

    /// PLAN REWRITE — typed accessor over `anchorType` for safe matching at the
    /// call sites that group/render the timeline by entry kind.
    enum AnchorKind: String {
        case fixed
        case routine
        case goalWork = "goal_work"
    }

    var anchorKind: AnchorKind {
        AnchorKind(rawValue: anchorType) ?? .goalWork
    }
}
