import Foundation
import SwiftData

@Model
final class Streak {
    var id: UUID = UUID()
    var currentCount: Int = 0
    var bestCount: Int = 0
    var lastActiveDate: Date = Date()

    // F3 — cadence-aware grace (optional/defaulted; additive migration).
    // Number of permitted "off" gaps remaining before a habitual streak resets.
    var freezesRemaining: Int = 2

    var goal: Goal?

    init() {
        self.id = UUID()
        self.currentCount = 0
        self.bestCount = 0
        self.lastActiveDate = .now
    }

    var isAlive: Bool {
        Calendar.current.isDateInToday(lastActiveDate) ||
        Calendar.current.isDateInYesterday(lastActiveDate)
    }

    func recordActivity() {
        if Calendar.current.isDateInToday(lastActiveDate) { return }
        if Calendar.current.isDateInYesterday(lastActiveDate) {
            currentCount += 1
        } else {
            currentCount = 1
        }
        if currentCount > bestCount {
            bestCount = currentCount
        }
        lastActiveDate = .now
    }

    /// Records activity for a habitual goal with an intended weekly cadence,
    /// applying non-punitive grace so off-days within the cadence don't reset the
    /// streak. A 3x/week goal completed Mon/Wed/Fri keeps climbing instead of
    /// resetting to 1 on the off days. For `timesPerWeek <= 0` this falls back to
    /// the consecutive-day behavior of `recordActivity()`.
    ///
    /// The maximum allowed gap is the cadence spacing (7 / timesPerWeek) plus one
    /// day of slack. Gaps within that window continue the streak. A gap larger than
    /// the window consumes a freeze (continuing the streak) if any remain, and only
    /// resets to 1 once grace is exhausted. Activity on the same day is a no-op.
    func recordActivity(forCadence timesPerWeek: Int) {
        guard timesPerWeek > 0 else {
            recordActivity()
            return
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastActiveDate) { return }

        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastActiveDate),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0

        // Allowed spacing for this cadence, with one day of slack.
        let allowedGap = Int((7.0 / Double(timesPerWeek)).rounded(.up)) + 1

        if daysSince <= allowedGap {
            currentCount += 1
            freezesRemaining = 2
        } else if freezesRemaining > 0 {
            freezesRemaining -= 1
            currentCount += 1
        } else {
            currentCount = 1
            freezesRemaining = 2
        }

        if currentCount > bestCount {
            bestCount = currentCount
        }
        lastActiveDate = .now
    }
}
