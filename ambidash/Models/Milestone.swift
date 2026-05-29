import Foundation
import SwiftData

/// A single checkpoint node in a goal's decomposition chain — the missing middle
/// between a long-range `Goal` and a same-day `PlannedAction`. One flexible
/// self-referential node type covers every band (year → quarter → month → week);
/// the `periodRaw` discriminator decides the variant, matching the codebase's
/// "one enum field decides the variant" convention (cf. Goal.horizonRaw).
///
/// CloudKit-safe: every relationship is optional or defaulted-empty; every new
/// scalar field is optional or defaulted (additive migration).
@Model
final class Milestone {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""

    /// Which cadence band this node sits in (see `MilestonePeriod`).
    var periodRaw: String = MilestonePeriod.month.rawValue

    /// Status string backing the shared `GoalStatus` enum, reused so the roadmap
    /// renders with the same StatusDot vocabulary as goals.
    var statusRaw: String = GoalStatus.onTrack.rawValue

    var startDate: Date = Date()
    var endDate: Date = Date()

    // Optional measurable key-result for this checkpoint. nil for non-measurable
    // checkpoints (a deliverable rather than a climbing number).
    var targetValue: Double? = nil
    var currentValue: Double? = nil
    var unit: String = ""

    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var completedAt: Date? = nil

    // Relationships — ALL optional or defaulted-empty for CloudKit.
    var goal: Goal?
    /// Self-reference up the year → quarter → month → week chain.
    var parentMilestone: Milestone?
    @Relationship(deleteRule: .cascade, inverse: \Milestone.parentMilestone)
    var childMilestones: [Milestone]?
    @Relationship(inverse: \PlannedAction.milestone)
    var actions: [PlannedAction]?

    init(
        title: String,
        period: MilestonePeriod,
        startDate: Date,
        endDate: Date,
        detail: String = "",
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        unit: String = "",
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.periodRaw = period.rawValue
        self.statusRaw = GoalStatus.onTrack.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.completedAt = nil
    }

    // MARK: - Computed accessors (mirrors Goal's enum-backed accessors)

    var period: MilestonePeriod {
        get { MilestonePeriod(rawValue: periodRaw) ?? .month }
        set { periodRaw = newValue.rawValue }
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .onTrack }
        set { statusRaw = newValue.rawValue }
    }

    /// True when this checkpoint carries a measurable key-result.
    var hasTarget: Bool {
        guard let targetValue else { return false }
        return targetValue != 0
    }

    /// Fraction (0...1) toward this checkpoint's target. Treats the checkpoint as
    /// a simple 0 → target climb (baseline 0), since a milestone is a slice of the
    /// goal's larger journey rather than a baseline-anchored metric.
    var percentComplete: Double {
        guard let targetValue, targetValue != 0 else { return 0 }
        let current = currentValue ?? 0
        return min(max(current / targetValue, 0), 1)
    }

    /// Whether the checkpoint has been explicitly marked done.
    var isCompleted: Bool {
        completedAt != nil
    }

    /// True when now falls inside this checkpoint's window.
    var isActiveNow: Bool {
        let now = Date.now
        return startDate <= now && now <= endDate
    }
}
