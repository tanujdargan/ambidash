import Foundation

/// Builds a real daily composite-score series from persisted `GoalProgress`
/// history, replacing the hardcoded mock sparkline on the dashboard.
///
/// Each active goal records (at most) one `GoalProgress` per day via
/// `GoalProgressTracker.recordDaily`. For any given calendar day we take, per
/// goal, the most recent score recorded on or before that day (carry-forward,
/// so a goal logged Monday still contributes Tuesday/Wednesday until it logs
/// again). Those per-goal scores are averaged into per-dimension scores exactly
/// the way `DimensionScoreCalculator` would for "today", then collapsed into a
/// single composite via `PulseScoreCalculator`. The result is a day-by-day
/// composite history that lines up with the live composite shown beside it.
enum CompositeHistoryCalculator {

    /// Daily composite scores over the trailing `days` window, oldest first,
    /// terminating at today. Days with no usable history fall back to a neutral
    /// 50 (matching `DimensionScoreCalculator`'s empty-dimension default) so the
    /// sparkline always has a continuous line to draw.
    ///
    /// - Parameters:
    ///   - goals: the goals to aggregate (caller passes the active set).
    ///   - days: number of trailing days to include (default 14).
    ///   - todayComposite: the live composite for today, used as the final point
    ///     so the series ends exactly where the big number reads.
    static func dailyComposite(
        from goals: [Goal],
        days: Int = 14,
        todayComposite: Int? = nil
    ) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Build the ordered list of day-starts, oldest -> today.
        let dayStarts: [Date] = (0..<max(days, 1)).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        let activeGoals = goals.filter { $0.isActive }

        // Pre-sort each goal's entries once (ascending by day) so the
        // carry-forward lookup per day is a simple scan.
        let entriesByGoal: [(goal: Goal, entries: [(day: Date, score: Int)])] = activeGoals.map { goal in
            let sorted = goal.progressEntries
                .map { (day: calendar.startOfDay(for: $0.date), score: $0.score) }
                .sorted { $0.day < $1.day }
            return (goal, sorted)
        }

        var series: [Double] = dayStarts.map { dayStart in
            composite(for: dayStart, entriesByGoal: entriesByGoal, calendar: calendar)
        }

        // Pin the final point to the live composite when provided so the
        // sparkline terminates exactly at the headline number.
        if let todayComposite, !series.isEmpty {
            series[series.count - 1] = Double(min(max(todayComposite, 0), 100))
        }

        return series
    }

    // MARK: - Private

    /// Composite for a single day: per-dimension average of each goal's most
    /// recent score on or before `dayStart`, then pulse across dimensions.
    private static func composite(
        for dayStart: Date,
        entriesByGoal: [(goal: Goal, entries: [(day: Date, score: Int)])],
        calendar: Calendar
    ) -> Double {
        // Accumulate per-dimension goal scores for this day.
        var perDimension: [LifeDimension: [Int]] = [:]

        for pair in entriesByGoal {
            guard let score = mostRecentScore(in: pair.entries, onOrBefore: dayStart) else { continue }
            perDimension[pair.goal.domain.dimension, default: []].append(score)
        }

        // Mirror DimensionScoreCalculator: every dimension contributes, empty
        // ones default to a neutral 50 so the composite stays comparable.
        var dimensionScores: [LifeDimension: Int] = [:]
        for dim in LifeDimension.allCases {
            if let scores = perDimension[dim], !scores.isEmpty {
                dimensionScores[dim] = scores.reduce(0, +) / scores.count
            } else {
                dimensionScores[dim] = 50
            }
        }

        return Double(PulseScoreCalculator.pulse(from: dimensionScores))
    }

    /// The score from the latest entry recorded on or before `dayStart`, or nil
    /// if the goal had no history by then. `entries` is ascending by day.
    private static func mostRecentScore(
        in entries: [(day: Date, score: Int)],
        onOrBefore dayStart: Date
    ) -> Int? {
        var result: Int?
        for entry in entries {
            if entry.day <= dayStart {
                result = entry.score
            } else {
                break
            }
        }
        return result
    }
}
