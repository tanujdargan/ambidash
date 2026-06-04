// ambidash/Services/ActivityInsights.swift
//
// v5 feat/v5-activity-logging — the pattern-detection + weekly-digest layer over the activity
// the app already logs (ActualEvent = what actually happened + when, EnergyCheckin = energy by
// time, Reflection = reflection habit). Turns that logged history into human-readable, CONFIDENCE-
// GATED insights ("You're most productive 9–11am", "You tend to skip afternoon goals") and folds
// them into a weekly digest. Pure and unit-testable: no SwiftData/SwiftUI dependency — the UI and
// a thin convenience layer feed it computed inputs.
import Foundation

/// One detected pattern, ready to render. `id` is stable per pattern KIND so the same insight
/// updates in place rather than duplicating across refreshes.
struct ActivityInsight: Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// How many data points backed this insight (shown as quiet "from N days/blocks" confidence).
    let sampleSize: Int
}

enum ActivityInsights {

    // Confidence floors — an insight is only surfaced when it's grounded in enough data, so we
    // never overfit a single day into a "pattern" (matching the app's non-overfit ethos).
    static let minHourSamples = 3
    static let minEnergySamples = 5
    static let afternoonGapThreshold = 0.25

    /// 12-hour label for an hour-of-day (0–23): 9 → "9am", 13 → "1pm", 0 → "12am".
    static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        let period = h < 12 ? "am" : "pm"
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve)\(period)"
    }

    /// Detect insights from already-computed inputs. Pure — the dicts come from
    /// LearningService.computeAdherenceByHour / computeEnergyByHour; counts are simple tallies.
    static func detect(
        adherenceByHour: [Int: (completed: Int, total: Int, ratio: Double)],
        energyByHour: [Int: Double],
        energySampleCount: Int,
        completedCount: Int,
        totalLoggedCount: Int,
        reflectionCount: Int
    ) -> [ActivityInsight] {
        var insights: [ActivityInsight] = []

        // 1. Most productive window — the best-adhering hour (with enough samples), framed as a
        // 2-hour window. "You're most productive 9–11am."
        let strongHours = adherenceByHour.filter { $0.value.total >= minHourSamples }
        if let best = strongHours.max(by: { lhs, rhs in
            lhs.value.ratio != rhs.value.ratio ? lhs.value.ratio < rhs.value.ratio : lhs.key > rhs.key
        }), best.value.ratio >= 0.5 {
            let start = best.key
            let end = (start + 2) % 24
            insights.append(ActivityInsight(
                id: "productive-window",
                title: "You're most productive \(hourLabel(start))–\(hourLabel(end))",
                detail: "You finish what you plan in this window more than any other.",
                symbol: "sunrise.fill",
                sampleSize: best.value.total
            ))
        }

        // 2. Afternoon skip tendency — afternoon adherence well below morning. "You tend to skip
        // afternoon goals."
        if let morning = aggregateRatio(adherenceByHour, hours: 5..<12),
           let afternoon = aggregateRatio(adherenceByHour, hours: 12..<17),
           morning.total >= minHourSamples, afternoon.total >= minHourSamples,
           morning.ratio - afternoon.ratio >= afternoonGapThreshold {
            insights.append(ActivityInsight(
                id: "afternoon-skip",
                title: "You tend to skip afternoon goals",
                detail: "Afternoons land less often than mornings — worth planning lighter then, or moving the important block earlier.",
                symbol: "sun.max",
                sampleSize: afternoon.total
            ))
        }

        // 3. Energy peak time-of-day — when reported energy is highest. "Your energy peaks in the
        // morning."
        if energySampleCount >= minEnergySamples,
           let peakHour = energyByHour.max(by: { $0.value < $1.value })?.key {
            insights.append(ActivityInsight(
                id: "energy-peak",
                title: "Your energy peaks \(partOfDay(peakHour))",
                detail: "Demanding work tends to go best around \(hourLabel(peakHour)).",
                symbol: "bolt.fill",
                sampleSize: energySampleCount
            ))
        }

        // 4. Completion rate — a warm, factual weekly tally (only once there's something logged).
        if totalLoggedCount >= minHourSamples {
            let pct = Int((Double(completedCount) / Double(max(1, totalLoggedCount)) * 100).rounded())
            insights.append(ActivityInsight(
                id: "completion-rate",
                title: "You finished \(completedCount) of \(totalLoggedCount) blocks (\(pct)%)",
                detail: "Partials count too — this is just what landed fully.",
                symbol: "checkmark.seal",
                sampleSize: totalLoggedCount
            ))
        }

        // 5. Reflection habit — encourage, never scold.
        if reflectionCount > 0 {
            insights.append(ActivityInsight(
                id: "reflection-habit",
                title: "You reflected \(reflectionCount) \(reflectionCount == 1 ? "day" : "days") this week",
                detail: "A small habit that compounds — nicely done.",
                symbol: "text.book.closed",
                sampleSize: reflectionCount
            ))
        }

        return insights
    }

    /// Combined completed/total ratio across a half-open hour range.
    private static func aggregateRatio(
        _ adherence: [Int: (completed: Int, total: Int, ratio: Double)], hours: Range<Int>
    ) -> (ratio: Double, total: Int)? {
        var completed = 0, total = 0
        for h in hours {
            if let b = adherence[h] { completed += b.completed; total += b.total }
        }
        guard total > 0 else { return nil }
        return (Double(completed) / Double(total), total)
    }

    private static func partOfDay(_ hour: Int) -> String {
        switch hour {
        case 5..<12: return "in the morning"
        case 12..<17: return "in the afternoon"
        case 17..<22: return "in the evening"
        default: return "at night"
        }
    }
}

/// A non-punitive weekly digest of the user's logged activity, surfaced once a week (or on demand).
struct WeeklyDigest: Equatable {
    var completedCount: Int = 0
    var partialCount: Int = 0
    var abandonedCount: Int = 0
    var totalLogged: Int = 0
    var averageEnergy: Double? = nil
    var reflectionCount: Int = 0
    var insights: [ActivityInsight] = []

    /// Whether there's enough logged activity to bother showing a digest.
    var hasContent: Bool { totalLogged > 0 || !insights.isEmpty }

    var averageEnergyLabel: String {
        guard let e = averageEnergy else { return "—" }
        return String(format: "%.1f / 5", e)
    }
}
