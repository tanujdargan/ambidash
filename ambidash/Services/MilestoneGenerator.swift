// ambidash/Services/MilestoneGenerator.swift
import Foundation
import SwiftData

/// A lightweight, model-free description of a checkpoint to be created. Mirrors
/// `PlanGenerator.ActionTemplate` — a draft the caller turns into a real
/// `Milestone` (inserting it and wiring up `goal`/`parentMilestone` inverses).
/// `parentIndex` references an earlier draft in the same array to express the
/// year → quarter → month → week tree (nil = top-level node), matching the AI
/// decompose contract's `parent_index`.
struct MilestoneDraft: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var period: MilestonePeriod
    var parentIndex: Int?
    var startDate: Date
    var endDate: Date
    var targetValue: Double?
    var unit: String
    var sortIndex: Int

    init(
        title: String,
        detail: String = "",
        period: MilestonePeriod,
        parentIndex: Int? = nil,
        startDate: Date,
        endDate: Date,
        targetValue: Double? = nil,
        unit: String = "",
        sortIndex: Int = 0
    ) {
        self.title = title
        self.detail = detail
        self.period = period
        self.parentIndex = parentIndex
        self.startDate = startDate
        self.endDate = endDate
        self.targetValue = targetValue
        self.unit = unit
        self.sortIndex = sortIndex
    }
}

/// Deterministic, offline milestone scaffolding — the fallback when AI decompose
/// is unavailable. Mirrors `PlanGenerator`: an `enum` namespace of pure static
/// helpers. The chain shape is derived from the goal's `GoalHorizon`:
///   - dream / build  →  year + quarter + month
///   - soon           →  quarter + month + week
///   - now            →  month + week
enum MilestoneGenerator {
    /// The ordered bands a default chain should contain for a given horizon,
    /// coarsest first. Each successive band nests under the previous one.
    static func chainPeriods(for horizon: GoalHorizon) -> [MilestonePeriod] {
        switch horizon {
        case .dream, .build: [.year, .quarter, .month]
        case .soon: [.quarter, .month, .week]
        case .now: [.month, .week]
        }
    }

    /// The [start, end) window for one node of `period` whose window contains or
    /// starts at `anchor`, snapped to the calendar (start of week/month/quarter/
    /// year). Returns a half-open-feeling closed window (end = next start − 1s).
    static func window(for period: MilestonePeriod, containing anchor: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start: Date
        switch period {
        case .year:
            start = calendar.dateInterval(of: .year, for: anchor)?.start
                ?? calendar.startOfDay(for: anchor)
        case .quarter:
            // Snap to the start of the calendar quarter containing `anchor`.
            let monthZeroBased = (calendar.component(.month, from: anchor) - 1)
            let quarterStartMonth = (monthZeroBased / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: anchor)
            comps.month = quarterStartMonth
            comps.day = 1
            start = calendar.date(from: comps) ?? calendar.startOfDay(for: anchor)
        case .month:
            start = calendar.dateInterval(of: .month, for: anchor)?.start
                ?? calendar.startOfDay(for: anchor)
        case .week:
            start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start
                ?? calendar.startOfDay(for: anchor)
        }
        let step = period.calendarStep
        let nextStart = calendar.date(byAdding: step.component, value: step.value, to: start) ?? start
        let end = nextStart.addingTimeInterval(-1)
        return (start, end)
    }

    /// Builds a deterministic checkpoint chain for `goal`, nesting one node of
    /// each band under the previous. Windows are anchored at "now" and snapped to
    /// the calendar so auto-generated and user-created milestones line up.
    static func defaultChain(for goal: Goal, calendar: Calendar = .current) -> [MilestoneDraft] {
        let periods = chainPeriods(for: goal.horizon)
        guard !periods.isEmpty else { return [] }

        let now = Date.now
        var drafts: [MilestoneDraft] = []
        var parentIndex: Int? = nil

        for (offset, period) in periods.enumerated() {
            let win = window(for: period, containing: now, calendar: calendar)
            let title = "\(period.displayName) checkpoint: \(goal.title)"
            let detail = "Auto-generated \(period.displayName.lowercased()) checkpoint toward \(goal.title)."
            let draft = MilestoneDraft(
                title: title,
                detail: detail,
                period: period,
                parentIndex: parentIndex,
                startDate: win.start,
                endDate: win.end,
                targetValue: nil,
                unit: goal.unit,
                sortIndex: offset
            )
            drafts.append(draft)
            parentIndex = drafts.count - 1
        }

        return drafts
    }

    /// Inserts a chain of `drafts` as real `Milestone`s on `goal`, wiring up the
    /// `goal` and `parentMilestone` inverses from the child side. Returns the
    /// created milestones in draft order (so callers can map indices). Does NOT
    /// save — the caller controls the transaction boundary.
    @discardableResult
    static func materialize(_ drafts: [MilestoneDraft], for goal: Goal, context: ModelContext) -> [Milestone] {
        var created: [Milestone] = []
        for draft in drafts {
            let milestone = Milestone(
                title: draft.title,
                period: draft.period,
                startDate: draft.startDate,
                endDate: draft.endDate,
                detail: draft.detail,
                targetValue: draft.targetValue,
                currentValue: draft.targetValue == nil ? nil : 0,
                unit: draft.unit,
                sortIndex: draft.sortIndex
            )
            context.insert(milestone)
            milestone.goal = goal
            if let pi = draft.parentIndex, pi >= 0, pi < created.count {
                milestone.parentMilestone = created[pi]
            }
            created.append(milestone)
        }
        return created
    }

    /// The active node of `period` for `goal` whose window contains now. When
    /// several exist (shouldn't normally), the one with the latest start wins.
    static func currentMilestone(for goal: Goal, period: MilestonePeriod) -> Milestone? {
        let now = Date.now
        return (goal.milestones ?? [])
            .filter { $0.period == period && $0.startDate <= now && now <= $0.endDate }
            .max { $0.startDate < $1.startDate }
    }
}
