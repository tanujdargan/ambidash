import Foundation

// MARK: - Breakdown math (mirrors the real scoring code, returns intermediates)

/// Recomputes the exact same numbers `DimensionScoreCalculator` and
/// `PulseScoreCalculator` produce, but exposes the intermediate values (per-goal
/// neglect band, attainment blend, pre-bonus dimension average, snapshot
/// bonus/penalty) so the breakdown card can show the honest math rather than an
/// invented formula. Keep this in lock-step with DimensionScoreCalculator.
///
/// This is pure, platform-agnostic logic (no SwiftUI / UIKit), so it lives in
/// Services and is shared by both the iOS `ScoreBreakdownCard` and the macOS
/// dashboard breakdown.
enum ScoreBreakdown {
    /// One goal's contribution to its dimension's average.
    struct GoalLine: Identifiable {
        let id: UUID
        let title: String
        let neglectDays: Int
        let neglectScore: Int
        /// Present only when the goal has a measurable target.
        let attainment: Int?
        /// The blended (or pure-neglect) score that feeds the dimension average.
        let finalScore: Int
        /// Human-readable trace of how `finalScore` was reached.
        var explanation: String {
            if let attainment {
                return "\(neglectScore) (\(bandLabel) neglect) + \(attainment) (\(attainment)% to target) ÷ 2 = \(finalScore)"
            }
            return "\(finalScore) (\(neglectDays)d since progress · \(bandLabel) band)"
        }
        private var bandLabel: String {
            switch neglectDays {
            case ...1: return "≤1d"
            case ...3: return "≤3d"
            case ...5: return "≤5d"
            case ...7: return "≤7d"
            default: return ">7d"
            }
        }
    }

    /// How a snapshot integration adjusted a dimension.
    struct Adjustment {
        let label: String       // e.g. "Sleep 7.5h"
        let bonusValue: Int     // the 0–100 value blended in
        let beforeScore: Int    // dimension average before blending
        let afterScore: Int     // after blending: (before + bonus) / 2
    }

    /// Full breakdown of one dimension.
    struct DimensionDetail {
        let dimension: LifeDimension
        let goalLines: [GoalLine]
        /// Average of goal scores (or 50 when the dimension has no goals).
        let baseScore: Int
        let hasGoals: Bool
        /// Snapshot bonus/penalty applied to this dimension, if any.
        let adjustment: Adjustment?
        /// The final dimension score shown on the arc gauge.
        let finalScore: Int
    }

    // Replicates DimensionScoreCalculator.goalScore (exact bands + blend).
    private static func neglectScore(forDays days: Int) -> Int {
        if days <= 1 { return 90 }
        if days <= 3 { return 75 }
        if days <= 5 { return 55 }
        if days <= 7 { return 40 }
        return max(10, 30 - (days - 7) * 3)
    }

    private static func goalLine(_ goal: Goal) -> GoalLine {
        let days = goal.neglectDays
        let neglect = neglectScore(forDays: days)
        if goal.hasTarget {
            let attainment = Int((goal.percentComplete * 100).rounded())
            return GoalLine(id: goal.id, title: goal.title, neglectDays: days,
                            neglectScore: neglect, attainment: attainment,
                            finalScore: (neglect + attainment) / 2)
        }
        return GoalLine(id: goal.id, title: goal.title, neglectDays: days,
                        neglectScore: neglect, attainment: nil, finalScore: neglect)
    }

    /// Detailed breakdown for one dimension, mirroring the production calculation.
    static func detail(for dimension: LifeDimension, goals: [Goal], snapshot: IntegrationSnapshot?) -> DimensionDetail {
        let dimGoals = goals.filter { $0.domain.dimension == dimension && $0.isActive }
        let lines = dimGoals.map(goalLine)

        let base: Int
        let hasGoals = !dimGoals.isEmpty
        if hasGoals {
            base = lines.map(\.finalScore).reduce(0, +) / lines.count
        } else {
            base = 50
        }

        var adjustment: Adjustment?
        var final = base
        if let snapshot {
            if dimension == .body, snapshot.sleepHours > 0 {
                let bonus = min(Int(snapshot.sleepHours / 8.0 * 100), 100)
                let after = (base + bonus) / 2
                adjustment = Adjustment(
                    label: "Sleep \(String(format: "%.1f", snapshot.sleepHours))h",
                    bonusValue: bonus, beforeScore: base, afterScore: after)
                final = after
            }
            if dimension == .craft, snapshot.screenTimeHours > 0 {
                let penalty = max(100 - Int(snapshot.screenTimeHours * 15), 0)
                let after = (base + penalty) / 2
                adjustment = Adjustment(
                    label: "Screen time \(String(format: "%.1f", snapshot.screenTimeHours))h",
                    bonusValue: penalty, beforeScore: base, afterScore: after)
                final = after
            }
        }

        return DimensionDetail(dimension: dimension, goalLines: lines,
                               baseScore: base, hasGoals: hasGoals,
                               adjustment: adjustment, finalScore: final)
    }
}

// MARK: - Breakdown sheet target

/// What the breakdown sheet is explaining: the composite average, or one
/// dimension's per-goal math.
enum ScoreBreakdownTarget: Identifiable, Hashable {
    case composite
    case dimension(LifeDimension)

    var id: String {
        switch self {
        case .composite: return "composite"
        case .dimension(let d): return "dim-\(d.rawValue)"
        }
    }
}
