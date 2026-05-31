import Foundation

enum DimensionScoreCalculator {
    static func scores(from goals: [Goal], snapshot: IntegrationSnapshot?) -> [LifeDimension: Int] {
        var result: [LifeDimension: Int] = [:]

        for dim in LifeDimension.allCases {
            let dimGoals = goals.filter { $0.domain.dimension == dim && $0.isActive }
            if dimGoals.isEmpty {
                result[dim] = 50
                continue
            }

            let avg = dimGoals.map { goalScore($0) }.reduce(0, +) / dimGoals.count
            result[dim] = avg
        }

        if let snapshot {
            if snapshot.sleepHours > 0 {
                let sleepBonus = min(Int(snapshot.sleepHours / 8.0 * 100), 100)
                result[.body] = ((result[.body] ?? 50) + sleepBonus) / 2
            }
            if snapshot.screenTimeHours > 0 {
                let screenPenalty = max(100 - Int(snapshot.screenTimeHours * 15), 0)
                result[.craft] = ((result[.craft] ?? 50) + screenPenalty) / 2
            }
        }

        return result
    }

    /// The step-function neglect band score (0–100) for a number of days since
    /// progress: ≤1d→90, ≤3d→75, ≤5d→55, ≤7d→40, else a slow decay. Exposed so UI
    /// (e.g. the recency progress bar) can mirror the actual scoring rather than a
    /// linear approximation.
    static func neglectBandScore(forDays days: Int) -> Int {
        if days <= 1 { return 90 }
        if days <= 3 { return 75 }
        if days <= 5 { return 55 }
        if days <= 7 { return 40 }
        return max(10, 30 - (days - 7) * 3)
    }

    private static func goalScore(_ goal: Goal) -> Int {
        let neglectScore = neglectBandScore(forDays: goal.neglectDays)

        guard goal.hasTarget else { return neglectScore }

        // Blend the recency/neglect band with measurable attainment.
        let attainment = Int((goal.percentComplete * 100).rounded())
        return (neglectScore + attainment) / 2
    }
}
