import Foundation
import SwiftData

/// v4 #4 + #6 — the multi-day planner. Owns the *logic* behind a customizable
/// 1–7 day look-ahead where tasks can be moved between days and the soonest big
/// commitment ("midterm in 2 days") is surfaced. Kept separate from the view so
/// the day-window math, find-or-create, move, and countdown are unit-testable
/// without a live SwiftUI context.
enum MultiDayPlannerService {

    /// Clamp the user-chosen day count into the supported 1…7 window.
    static func clampedCount(_ raw: Int) -> Int { min(max(raw, 1), 7) }

    /// The N day-starts beginning at `from`'s day (day 0 = today). Always returns
    /// `clampedCount(count)` entries, normalized to startOfDay.
    static func days(from: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: from)
        return (0..<clampedCount(count)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    /// Find the DailyPlan for `date`, creating + inserting one if absent. The
    /// `format` of a freshly created plan mirrors `formatHint` (falls back to
    /// focus blocks) so a moved task lands in a sensibly-shaped day.
    @discardableResult
    static func planFor(_ date: Date, in plans: [DailyPlan], context: ModelContext,
                        formatHint: PlanFormat = .focusBlocks, calendar: Calendar = .current) -> DailyPlan {
        if let existing = plans.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return existing
        }
        let created = DailyPlan(date: calendar.startOfDay(for: date), format: formatHint)
        context.insert(created)
        return created
    }

    /// Move `action` to the plan for `targetDate` — a TRUE reassignment (one
    /// identity, no clone). No-ops if it's already on that day. Recomputes the
    /// affected plans' `actionCount`. Returns the destination plan.
    @discardableResult
    static func move(_ action: PlannedAction, to targetDate: Date, in plans: [DailyPlan],
                     context: ModelContext, calendar: Calendar = .current) -> DailyPlan {
        let source = action.plan
        let hint = PlanFormat(rawValue: action.plan?.formatRaw ?? "") ?? .focusBlocks
        let dest = planFor(targetDate, in: plans, context: context, formatHint: hint, calendar: calendar)

        if let source, calendar.isDate(source.date, inSameDayAs: dest.date) { return dest }

        action.plan = dest
        if let source { source.actionCount = max((source.actions?.count ?? 1) - 1, 0) }
        dest.actionCount = (dest.actions?.count ?? 0)
        return dest
    }

    /// When a milestone is <=3 days away, returns planning suggestions that prioritize
    /// preparation for that event over routine tasks. Routine/fixed anchors are
    /// deferrable; goal-work tied to the milestone (or untied goal-work) is kept.
    /// Returns nil when nothing is imminent.
    static func bigEventPlanAdjustments(
        milestones: [Milestone],
        todayActions: [PlannedAction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BigEventAdjustment? {
        let today = calendar.startOfDay(for: now)
        let imminent: [(Milestone, Int)] = milestones.compactMap { m in
            guard m.completedAt == nil else { return nil }
            let day = calendar.startOfDay(for: m.endDate)
            let delta = calendar.dateComponents([.day], from: today, to: day).day ?? -1
            guard delta >= 0, delta <= 3 else { return nil }
            return (m, delta)
        }
        guard let (milestone, days) = imminent.sorted(by: {
            $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.title < $1.0.title
        }).first else { return nil }

        var priority: [String] = []
        var deferrable: [String] = []

        for action in todayActions {
            let kind = action.anchorKind
            let tiedToEvent = action.goalID != nil && action.goalID == milestone.goal?.id
            if kind == .goalWork || tiedToEvent {
                priority.append(action.title)
            } else if kind == .routine {
                deferrable.append(action.title)
            }
        }

        let eventPhrase: String
        switch days {
        case 0: eventPhrase = "today"
        case 1: eventPhrase = "tomorrow"
        default: eventPhrase = "in \(days) days"
        }

        let suggestion = "\(milestone.title) is \(eventPhrase) \u{2014} focus prep today"
            + (deferrable.isEmpty ? "." : ", defer \(deferrable.count) routine \(deferrable.count == 1 ? "item" : "items").")

        return BigEventAdjustment(
            milestone: milestone,
            daysUntil: days,
            priorityActions: priority,
            deferrableActions: deferrable,
            suggestion: suggestion
        )
    }

    /// The soonest open (incomplete) milestone deadline within `horizonDays`, as a
    /// big-event countdown. Past-due deadlines are excluded (a future-facing nudge),
    /// ties break on the earlier endDate then title for determinism. Returns nil
    /// when nothing dated is coming up.
    static func soonestBigEvent(milestones: [Milestone], from: Date = .now,
                                horizonDays: Int = 14, calendar: Calendar = .current) -> BigEventCountdown? {
        let today = calendar.startOfDay(for: from)
        let candidates: [BigEventCountdown] = milestones.compactMap { m in
            guard m.completedAt == nil else { return nil }
            let day = calendar.startOfDay(for: m.endDate)
            let delta = calendar.dateComponents([.day], from: today, to: day).day ?? -1
            guard delta >= 0, delta <= horizonDays else { return nil }
            return BigEventCountdown(title: m.title, daysUntil: delta, date: day)
        }
        return candidates.sorted {
            $0.daysUntil != $1.daysUntil ? $0.daysUntil < $1.daysUntil : $0.title < $1.title
        }.first
    }
}

/// A dated commitment surfaced ahead of time so it's visible before it arrives.
struct BigEventCountdown: Equatable {
    let title: String
    let daysUntil: Int
    let date: Date

    /// "Today" / "Tomorrow" / "in N days" — the human countdown phrase.
    var phrase: String {
        switch daysUntil {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(daysUntil) days"
        }
    }
}

/// The result of big-event plan adjustment: which actions to keep and which can wait.
struct BigEventAdjustment {
    let milestone: Milestone
    let daysUntil: Int
    let priorityActions: [String]
    let deferrableActions: [String]
    let suggestion: String

    var countdownPhrase: String {
        switch daysUntil {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(daysUntil) days"
        }
    }
}
