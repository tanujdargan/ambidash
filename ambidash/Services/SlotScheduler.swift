// ambidash/Services/SlotScheduler.swift
import Foundation

/// A2 / #10 — assigns concrete clock time slots to a day's actions from the real
/// calendar free-minute budget (sourced from `EventKitService.computeFreeMinutes`
/// via `IntegrationSnapshot.calendarFreeMinutes`), instead of the old fixed slot
/// array. The scheduler lays actions back-to-back inside the waking window,
/// proportionally compressing the spacing when the free budget is tight so a busy
/// day's actions cluster into the gaps that remain. When no real free-minute
/// signal is available it falls back to the historical fixed slots, so behaviour
/// is unchanged for users without calendar access.
enum SlotScheduler {
    /// The historical fixed slots, used as the fallback when EventKit data is
    /// unavailable (no snapshot, or a non-positive free-minute budget).
    static let fallbackSlots = ["07:00", "08:30", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"]

    /// The start of the waking planning window (24h hour). Mirrors EventKitService.
    private static let wakeHour = 7
    /// The end of the waking planning window (24h hour). Mirrors EventKitService.
    private static let sleepHour = 23

    /// Returns a clock time slot ("HH:MM") for each action index `0..<count`,
    /// spacing them across the waking day sized to `freeMinutes` of real free time
    /// and the actions' own durations.
    ///
    /// - Parameters:
    ///   - count: how many actions need a slot.
    ///   - durations: per-action duration in minutes (parallel to the returned
    ///     array). Used to advance the clock realistically between slots.
    ///   - freeMinutes: the calendar free-minute budget from the snapshot. When
    ///     `nil` or `<= 0`, falls back to the fixed slot array.
    /// - Returns: `count` time-slot strings.
    static func assignSlots(count: Int, durations: [Int], freeMinutes: Int?) -> [String] {
        guard count > 0 else { return [] }

        // Fallback path: no real signal → fixed slots (with blanks past the array).
        guard let free = freeMinutes, free > 0 else {
            return (0..<count).map { i in i < fallbackSlots.count ? fallbackSlots[i] : "" }
        }

        // The full waking window in minutes, and the per-gap spacing we can afford.
        let windowMinutes = max((sleepHour - wakeHour) * 60, 60)
        let plannedDuration = durations.prefix(count).reduce(0, +)

        // Distribute the day across the actions. Each action gets a share of the
        // window proportional to the free budget: when free time is plentiful we
        // spread out to the full window; when it's tight we pack into `free`.
        let usableSpan = min(windowMinutes, max(free, plannedDuration))
        // Gap between the START of consecutive actions. Guard count==1.
        let gap = count > 1 ? max(usableSpan / count, 15) : 0

        var slots: [String] = []
        var cursor = wakeHour * 60 // minutes from midnight
        let dayEnd = sleepHour * 60

        for i in 0..<count {
            let clamped = min(cursor, dayEnd - 5)
            slots.append(formatMinutes(clamped))
            // Advance by the larger of the proportional gap and this action's own
            // duration so slots never visibly overlap their predecessor.
            let dur = i < durations.count ? durations[i] : 30
            cursor += max(gap, dur)
        }
        return slots
    }

    /// Formats minutes-from-midnight as a zero-padded "HH:MM" clock string.
    private static func formatMinutes(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}
