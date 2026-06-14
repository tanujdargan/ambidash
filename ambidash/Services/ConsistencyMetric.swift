import Foundation

// Phase 1 (retention) — a non-punitive CONSISTENCY metric to replace brittle all-or-
// nothing streaks as the headline number, plus capped streak-repair.
//
// The plan + ND research: streaks that snap to zero on one missed day punish exactly
// the users who most need grace. Consistency is a rolling fraction (0…1) of the
// expected cadence actually met over a window — a 90% month reads as "strong", not
// "failed", even with a gap. Streak-repair lets a short lapse be mended (within a cap)
// instead of resetting. All pure + testable.
enum ConsistencyMetric {

    /// Rolling consistency (0…1): distinct active days in the window ÷ days the cadence
    /// expected. Capped at 1.0 (over-delivering doesn't inflate past "fully consistent").
    /// `timesPerWeek <= 0` (a daily/identity habit) is treated as 7×/week.
    static func consistency(loggedDates: [Date], timesPerWeek: Int, windowDays: Int = 28,
                            now: Date = .now, calendar: Calendar = .current) -> Double {
        guard windowDays > 0 else { return 0 }
        let cadence = timesPerWeek > 0 ? timesPerWeek : 7
        let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(-Double(windowDays) * 86_400)
        let distinctDays = Set(
            loggedDates
                .filter { $0 >= cutoff && $0 <= now }
                .map { calendar.startOfDay(for: $0) }
        ).count
        let expected = Double(cadence) * Double(windowDays) / 7.0
        guard expected > 0 else { return 0 }
        return min(1.0, Double(distinctDays) / expected)
    }

    /// A warm, non-punitive band label for a consistency fraction.
    static func band(_ consistency: Double) -> String {
        switch consistency {
        case 0.85...: return "Rock solid"
        case 0.6..<0.85: return "Strong"
        case 0.3..<0.6: return "Building"
        default: return "Just starting"
        }
    }

    /// Whether a lapsed streak can still be REPAIRED rather than reset. A gap up to
    /// `repairWindowDays` (default 2) beyond the cadence's allowed spacing is mendable —
    /// the user can log the missed day and keep the run, capped so it's grace, not gaming.
    static func canRepair(daysSinceLastActive: Int, timesPerWeek: Int, repairWindowDays: Int = 2) -> Bool {
        let cadence = timesPerWeek > 0 ? timesPerWeek : 7
        let allowedGap = Int((7.0 / Double(cadence)).rounded(.up)) + 1
        return daysSinceLastActive > allowedGap && daysSinceLastActive <= allowedGap + repairWindowDays
    }

    /// Apply a repair: the run continues (count + 1) when within the repair window,
    /// otherwise it resets to 1 (today counts). Non-punitive either way.
    static func repairedCount(currentCount: Int, daysSinceLastActive: Int,
                              timesPerWeek: Int, repairWindowDays: Int = 2) -> Int {
        let cadence = timesPerWeek > 0 ? timesPerWeek : 7
        let allowedGap = Int((7.0 / Double(cadence)).rounded(.up)) + 1
        if daysSinceLastActive <= allowedGap { return currentCount + 1 }               // on schedule
        if daysSinceLastActive <= allowedGap + repairWindowDays { return currentCount + 1 } // repaired
        return 1                                                                        // reset, gently
    }
}
