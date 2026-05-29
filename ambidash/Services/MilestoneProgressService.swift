// ambidash/Services/MilestoneProgressService.swift
import Foundation
import SwiftData

/// Rolls progress contributions UP a Milestone's `parentMilestone` chain and
/// recomputes each touched node's status. Analogue of `GoalProgressTracker`, but
/// where the tracker scores a goal from neglect/cadence/target, this service
/// scores a checkpoint from how much of its key-result is done relative to how
/// much of its time window has elapsed (pace), plus end-date proximity.
///
/// Status rules (documented per the C1 risk note):
///   - paused      : the checkpoint is explicitly completed (completedAt set).
///   - onTrack     : percentComplete >= elapsed-fraction of the window
///                   (i.e. at or ahead of pace), OR no target and not overdue.
///   - needsAttention : behind pace but within tolerance, or window ending soon
///                   (<= 20% of the window remaining) and not yet complete.
///   - slipping    : window has ended without completion, or far behind pace.
/// (`paused` is reused only to render a distinct "done" dot; completion is also
/// surfaced via `isCompleted`.)
enum MilestoneProgressService {
    /// Adds `amount` to `milestone.currentValue` (initializing nil to 0), then
    /// propagates the same increment up every ancestor that carries a target,
    /// and refreshes status on each touched node. Mirrors the cascade a child
    /// action's contribution makes toward its month/quarter/year ancestors.
    /// Does NOT save — the caller owns the transaction.
    static func contribute(amount: Double, to milestone: Milestone, context: ModelContext) {
        guard amount != 0 else {
            // Even a zero contribution should refresh status (e.g. a check-in
            // that only marks the window touched).
            refreshStatus(of: milestone)
            propagateStatus(from: milestone)
            return
        }

        var node: Milestone? = milestone
        while let current = node {
            // Only roll the number into ancestors that actually track a target;
            // a non-measurable ancestor stays a pure container.
            if current.hasTarget || current === milestone {
                current.currentValue = (current.currentValue ?? 0) + amount
            }
            refreshStatus(of: current)
            node = current.parentMilestone
        }
    }

    /// Marks a checkpoint complete (sets completedAt + clamps currentValue to
    /// target if measurable) and refreshes the chain's status. Does NOT save.
    static func markComplete(_ milestone: Milestone, context: ModelContext) {
        milestone.completedAt = .now
        if let target = milestone.targetValue {
            milestone.currentValue = target
        }
        refreshStatus(of: milestone)
        propagateStatus(from: milestone)
    }

    /// Recomputes `milestone.status` from its measurable pace and window
    /// proximity. Pure: touches only the passed node's `statusRaw`.
    static func refreshStatus(of milestone: Milestone) {
        if milestone.isCompleted {
            milestone.status = .paused
            return
        }

        let now = Date.now
        let elapsedFraction = windowElapsedFraction(of: milestone, now: now)
        let remainingFraction = 1 - elapsedFraction
        let overdue = now > milestone.endDate

        if milestone.hasTarget {
            let pct = milestone.percentComplete
            if pct >= 1 {
                milestone.status = .onTrack
            } else if overdue {
                milestone.status = .slipping
            } else if pct >= elapsedFraction {
                // At or ahead of pace.
                milestone.status = .onTrack
            } else if pct >= elapsedFraction - 0.15 || remainingFraction > 0.2 {
                // Behind, but recoverable / time still left.
                milestone.status = .needsAttention
            } else {
                milestone.status = .slipping
            }
        } else {
            // Non-measurable checkpoint: judged purely by window proximity.
            if overdue {
                milestone.status = .slipping
            } else if remainingFraction <= 0.2 {
                milestone.status = .needsAttention
            } else {
                milestone.status = .onTrack
            }
        }
    }

    /// Refreshes status from `milestone` up through every ancestor.
    static func propagateStatus(from milestone: Milestone) {
        var node: Milestone? = milestone.parentMilestone
        while let current = node {
            refreshStatus(of: current)
            node = current.parentMilestone
        }
    }

    /// Elapsed fraction (0...1) of the checkpoint's time window as of `now`.
    /// Degenerate windows (end <= start) report fully elapsed.
    static func windowElapsedFraction(of milestone: Milestone, now: Date = .now) -> Double {
        let span = milestone.endDate.timeIntervalSince(milestone.startDate)
        guard span > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(milestone.startDate)
        return min(max(elapsed / span, 0), 1)
    }
}
