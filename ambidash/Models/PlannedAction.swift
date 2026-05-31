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

    // MARK: - ZERO-GUILT LIFECYCLE (differentiator #2 — abolish the red overdue pile)

    /// ZERO-GUILT — the richer, non-punitive lifecycle state of this action,
    /// resolved via `LifecycleState` (unknown → `.pending`). This is ADDITIVE on top
    /// of the legacy `statusRaw` ("pending"/"done"/"skipped") which every existing
    /// surface still reads. States:
    /// - `pending`   → not yet acted on (mirrors statusRaw "pending")
    /// - `partial`   → honored partial progress (2 of 5) — see `partialProgress`
    /// - `deferred`  → gently rolled forward, NOT missed — see `deferredFrom`
    /// - `rest`      → "I chose not to, and that's okay" — a first-class rest state
    /// - `done`      → completed (mirrors statusRaw "done")
    /// - `abandoned` → let go without judgment (archive) — see CarryOverService
    ///
    /// CONTRACT (kept in sync so no surface regresses): whenever lifecycle changes,
    /// `statusRaw` is mirrored via `applyLifecycle(_:)`:
    ///   done → statusRaw "done"; pending/partial/deferred/rest → "pending"
    ///   (so they keep gently rolling forward and never read as a hard skip);
    ///   abandoned → statusRaw "skipped" (settled, left behind, never re-carried).
    /// Legacy "skipped" with no lifecycle set continues to read as a soft set-aside.
    /// Defaulted/additive (CloudKit-safe).
    var lifecycleRaw: String = "pending"

    /// ZERO-GUILT — fraction of the action completed, 0…1. 0 = untouched, 1 = fully
    /// done; 0.4 honors "2 of 5". Drives the partial progress badge and lets credit
    /// be proportional rather than all-or-nothing. Defaulted (CloudKit-safe).
    var partialProgress: Double = 0

    /// ZERO-GUILT — the date this action was last gently rolled forward FROM, set
    /// when it is `deferred`. Framed "deferred until tomorrow", NEVER "missed". nil
    /// when the action was never deferred. Distinct from `carriedOverFrom` (the
    /// idempotency/lineage stamp on the CLONE): `deferredFrom` records the user's
    /// intent on the ORIGINAL. Defaulted (CloudKit-safe).
    var deferredFrom: Date? = nil

    /// ZERO-GUILT — optional gentle, user-facing reason a deferral carries forward
    /// (e.g. "low energy", "ran out of day"). Empty when none. Surfaced softly as
    /// context, never as a justification the user owes. Defaulted (CloudKit-safe).
    var deferralReason: String = ""

    /// ZERO-GUILT — true when this action is a logged REST marker ("rest day / I
    /// chose not to, and that's okay"). A legitimate, first-class state — rest is not
    /// absence. Defaulted (CloudKit-safe).
    var restMarker: Bool = false

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
        self.lifecycleRaw = "pending"
        self.partialProgress = 0
        self.deferredFrom = nil
        self.deferralReason = ""
        self.restMarker = false
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

    // MARK: - ZERO-GUILT lifecycle (typed accessor + statusRaw mirror)

    /// The richer non-punitive lifecycle states. STRING-keyed with a safe fallback so
    /// an older client (or a value it doesn't know) resolves to `.pending` — additive
    /// and forward-compatible, never a crash.
    enum LifecycleState: String, CaseIterable {
        case pending
        case partial
        case deferred
        case rest
        case done
        case abandoned

        /// Calm, non-punitive label. NOTHING here reads as failure.
        var label: String {
            switch self {
            case .pending: return "Planned"
            case .partial: return "In progress"
            case .deferred: return "Deferred — it rolls forward"
            case .rest: return "Rest — and that's okay"
            case .done: return "Done"
            case .abandoned: return "Let go"
            }
        }

        /// SF Symbol for the timeline badge. `deferred` uses a forward arrow (rolls
        /// on), `rest` a moon, `partial` a half-circle — never a warning/error glyph.
        var symbol: String {
            switch self {
            case .pending: return "circle"
            case .partial: return "circle.lefthalf.filled"
            case .deferred: return "arrow.turn.down.right"
            case .rest: return "moon.stars"
            case .done: return "checkmark.circle.fill"
            case .abandoned: return "archivebox"
            }
        }
    }

    /// Typed accessor over `lifecycleRaw`. Setting it ALSO mirrors `statusRaw` so the
    /// legacy contract every existing surface reads stays consistent (see the
    /// `lifecycleRaw` doc for the mapping). Use this — not raw assignment — to change
    /// lifecycle so the mirror is never skipped.
    var lifecycle: LifecycleState {
        get {
            // Prefer the explicit lifecycle. When it's still the default `.pending`
            // (e.g. a legacy action mutated only via `statusRaw` by the Today screens,
            // or pre-migration data), DERIVE from `statusRaw` so the dual state never
            // drifts: a legacy "done"/"skipped" reads correctly without a migration.
            let explicit = LifecycleState(rawValue: lifecycleRaw) ?? .pending
            guard explicit == .pending else { return explicit }
            switch statusRaw {
            case "done": return .done
            case "skipped": return restMarker ? .rest : .pending
            default: return restMarker ? .rest : .pending
            }
        }
        set { applyLifecycle(newValue) }
    }

    /// Mirror a lifecycle change onto `lifecycleRaw` + the legacy `statusRaw`, keeping
    /// the dual state in sync (the documented CONTRACT). Also stamps the side fields
    /// (`restMarker`, `completedAt`) so the model stays internally consistent.
    func applyLifecycle(_ state: LifecycleState) {
        lifecycleRaw = state.rawValue
        switch state {
        case .done:
            statusRaw = "done"
            if completedAt == nil { completedAt = .now }
            partialProgress = 1
            restMarker = false
        case .abandoned:
            // Settled + left behind: a legacy "skipped" so CarryOverService never
            // re-carries it. Non-punitive — "let it go", not "failed".
            statusRaw = "skipped"
            restMarker = false
        case .rest:
            // First-class rest. Keep statusRaw pending so it isn't a hard skip, but
            // it is excluded from carry-forward (rest isn't unfinished work).
            statusRaw = "pending"
            restMarker = true
        case .pending, .partial, .deferred:
            // Keep gently rolling forward — never a hard skip.
            statusRaw = "pending"
            restMarker = false
        }
    }
}
