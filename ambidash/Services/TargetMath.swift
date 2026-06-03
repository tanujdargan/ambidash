import Foundation

/// Pace state for a measurable goal: where its current value sits relative to
/// where it "should" be today given the elapsed fraction of its horizon timeframe.
enum TargetVariance: String, Codable {
    case behind, onTrack, ahead
}

enum TargetMath {
    /// Approximate horizon duration in days, used to project an expected pace.
    static func horizonDays(_ horizon: GoalHorizon) -> Double {
        switch horizon {
        case .now: 90
        case .soon: 365
        case .build: 730
        case .dream: 2190
        }
    }

    static func percentComplete(_ goal: Goal) -> Double {
        goal.percentComplete
    }

    /// Elapsed fraction (0...1) of the goal's horizon timeframe since createdAt.
    static func expectedPaceFraction(_ goal: Goal) -> Double {
        let total = horizonDays(goal.horizon)
        guard total > 0 else { return 0 }
        let elapsed = Date.now.timeIntervalSince(goal.createdAt) / 86_400.0
        return min(max(elapsed / total, 0), 1)
    }

    /// The value the goal "should" be at today if progressing linearly toward target.
    static func expectedValue(_ goal: Goal) -> Double {
        let fraction = expectedPaceFraction(goal)
        return goal.baselineValue + (goal.targetValue - goal.baselineValue) * fraction
    }

    /// Compares currentValue against expectedValue per direction with a small tolerance.
    static func variance(_ goal: Goal) -> TargetVariance {
        guard goal.hasTarget else { return .onTrack }
        let expected = expectedValue(goal)
        let span = abs(goal.targetValue - goal.baselineValue)
        let tolerance = span * 0.05
        switch goal.direction {
        case .increase:
            if goal.currentValue > expected + tolerance { return .ahead }
            if goal.currentValue < expected - tolerance { return .behind }
            return .onTrack
        case .decrease:
            if goal.currentValue < expected - tolerance { return .ahead }
            if goal.currentValue > expected + tolerance { return .behind }
            return .onTrack
        }
    }

    /// Real logged resulting values within the window, oldest-to-newest.
    static func recentValues(for goal: Goal, days: Int = 14) -> [Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now.addingTimeInterval(-Double(days) * 86400)
        return (goal.progressLogs ?? [])
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map(\.resultingValue)
    }
}
