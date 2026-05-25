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
                result[.focus] = ((result[.focus] ?? 50) + screenPenalty) / 2
            }
        }

        return result
    }

    private static func goalScore(_ goal: Goal) -> Int {
        let days = goal.neglectDays
        if days <= 1 { return 90 }
        if days <= 3 { return 75 }
        if days <= 5 { return 55 }
        if days <= 7 { return 40 }
        return max(10, 30 - (days - 7) * 3)
    }
}
