import Foundation

enum PulseScoreCalculator {
    static func pulse(from dimensionScores: [LifeDimension: Int]) -> Int {
        guard !dimensionScores.isEmpty else { return 50 }
        let total = dimensionScores.values.reduce(0, +)
        let avg = total / dimensionScores.count
        return min(max(avg, 0), 100)
    }
}
