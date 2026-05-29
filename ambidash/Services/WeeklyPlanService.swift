// ambidash/Services/WeeklyPlanService.swift
import Foundation
import SwiftData

/// C2 — forward planning at the weekly and monthly cadence, expressed entirely
/// through the existing `Milestone` entity (zero new @Model types). A weekly
/// commitment is simply a `.week`-period Milestone owned by a goal; a monthly
/// objective is a `.month`-period Milestone. This service is the get-or-create
/// gateway for those planning nodes, so the daily planner and the review screens
/// all converge on the *same* milestone for a given goal + calendar window.
///
/// Mirrors `MilestoneGenerator` / `PlanGenerator`: an `enum` namespace of pure
/// static helpers, no instances. ALL window math is delegated to
/// `MilestoneGenerator.window(for:containing:calendar:)` so auto-created planning
/// milestones snap to the exact same calendar boundaries as the roadmap chain.
///
/// CloudKit-safe: creates nothing but `Milestone`s (all-optional/defaulted
/// schema) and wires the `goal` inverse on the child side. Does NOT save — the
/// caller owns the transaction boundary, matching `MilestoneGenerator`.
enum WeeklyPlanService {
    // MARK: - Week

    /// The goal's active `.week`-period Milestone whose window contains now, if
    /// one exists. When several overlap (shouldn't normally), the latest-starting
    /// one wins — consistent with `MilestoneGenerator.currentMilestone`.
    static func currentWeekMilestone(for goal: Goal) -> Milestone? {
        MilestoneGenerator.currentMilestone(for: goal, period: .week)
    }

    /// Get-or-create this calendar week's `.week`-period Milestone for `goal`.
    /// Returns the existing active week commitment when present; otherwise creates
    /// one snapped to the current calendar week (window via
    /// `MilestoneGenerator.window(for: .week, containing: .now)`), titled
    /// "<goal>: this week", owned by the goal. Does NOT save.
    @discardableResult
    static func ensureWeekMilestone(for goal: Goal, context: ModelContext, calendar: Calendar = .current) -> Milestone {
        ensureMilestone(for: goal, period: .week, titleSuffix: "this week", context: context, calendar: calendar)
    }

    // MARK: - Month

    /// The goal's active `.month`-period Milestone whose window contains now, if
    /// one exists. Latest-starting wins when several overlap.
    static func currentMonthMilestone(for goal: Goal) -> Milestone? {
        MilestoneGenerator.currentMilestone(for: goal, period: .month)
    }

    /// Get-or-create this calendar month's `.month`-period Milestone for `goal`.
    /// Returns the existing active month objective when present; otherwise creates
    /// one snapped to the current calendar month, titled "<goal>: this month",
    /// owned by the goal. Does NOT save.
    @discardableResult
    static func ensureMonthMilestone(for goal: Goal, context: ModelContext, calendar: Calendar = .current) -> Milestone {
        ensureMilestone(for: goal, period: .month, titleSuffix: "this month", context: context, calendar: calendar)
    }

    // MARK: - Daily planner convenience

    /// The week-period commitment a freshly generated daily action should roll up
    /// into. Convenience alias for `currentWeekMilestone` so the daily planner can
    /// read intent at the call site; callers that want creation-on-demand use
    /// `ensureWeekMilestone` instead.
    static func activeWeekMilestone(for goal: Goal) -> Milestone? {
        currentWeekMilestone(for: goal)
    }

    // MARK: - Shared get-or-create

    /// Get-or-create the active node of `period` for `goal`, snapped to the
    /// current calendar window. Single implementation behind the week/month
    /// public faces so window math and ownership wiring stay identical.
    private static func ensureMilestone(
        for goal: Goal,
        period: MilestonePeriod,
        titleSuffix: String,
        context: ModelContext,
        calendar: Calendar
    ) -> Milestone {
        if let existing = MilestoneGenerator.currentMilestone(for: goal, period: period) {
            return existing
        }

        let win = MilestoneGenerator.window(for: period, containing: .now, calendar: calendar)
        let milestone = Milestone(
            title: "\(goal.title): \(titleSuffix)",
            period: period,
            startDate: win.start,
            endDate: win.end,
            detail: "",
            targetValue: nil,
            currentValue: nil,
            unit: goal.unit,
            sortIndex: 0
        )
        context.insert(milestone)
        milestone.goal = goal
        // C2 — wire the freshly created planning node into the goal's existing
        // checkpoint chain so completing its actions rolls up to the targeted
        // month/quarter/year ancestors. Without a parent, a target-less week/month
        // node is an orphan and MilestoneProgressService.contribute has nothing to
        // propagate into. Mirrors AddMilestoneView.save() / MilestoneGenerator.materialize.
        milestone.parentMilestone = nearestCoarserMilestone(for: goal, finerThan: period)
        MilestoneProgressService.refreshStatus(of: milestone)
        MilestoneProgressService.propagateStatus(from: milestone)
        return milestone
    }

    /// The goal's current active checkpoint at the nearest coarser band above
    /// `period` (week → month → quarter → year). Walks outward so a new `.week`
    /// node still finds a `.quarter` or `.year` ancestor when no `.month` node
    /// exists (e.g. dream/build goals whose default chain is year/quarter/month).
    private static func nearestCoarserMilestone(for goal: Goal, finerThan period: MilestonePeriod) -> Milestone? {
        var coarser = nextCoarserBand(after: period)
        while let band = coarser {
            if let node = MilestoneGenerator.currentMilestone(for: goal, period: band) {
                return node
            }
            coarser = nextCoarserBand(after: band)
        }
        return nil
    }

    /// The next coarser cadence band above `period` (week→month→quarter→year),
    /// or nil at the top (year has no coarser parent).
    private static func nextCoarserBand(after period: MilestonePeriod) -> MilestonePeriod? {
        switch period {
        case .week: return .month
        case .month: return .quarter
        case .quarter: return .year
        case .year: return nil
        }
    }
}
