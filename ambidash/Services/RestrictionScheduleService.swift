// ambidash/Services/RestrictionScheduleService.swift
//
// v5 feat/v5-app-restrictions — the PURE scheduling + reporting logic behind scheduled
// restriction windows and the weekly usage report. Deliberately free of any Family Controls /
// DeviceActivity dependency so it's fully unit-testable on the Simulator (where the real
// shielding can't run). The AppLimitController consumes these decisions to drive the device-only
// DeviceActivityCenter registration.
import Foundation

enum RestrictionSchedule {

    // MARK: - Weekday mask helpers
    //
    // A 7-bit set: bit i (0 = Sunday … 6 = Saturday). Matches Calendar's `.weekday`
    // component (1 = Sunday … 7 = Saturday) shifted down by one.

    static let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let weekdaysMask = 0b1111111
    static let weekdaysMonFri = 0b0111110
    static let weekendMask = 0b1000001

    /// 0 = Sunday … 6 = Saturday for a given date.
    static func weekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    /// Build a mask from explicit 0…6 weekday indices.
    static func mask(from weekdays: [Int]) -> Int {
        weekdays.reduce(0) { $0 | (1 << $1) }
    }

    /// The sorted 0…6 weekday indices set in a mask.
    static func weekdays(from mask: Int) -> [Int] {
        (0..<7).filter { mask & (1 << $0) != 0 }
    }

    static func contains(_ mask: Int, weekday index: Int) -> Bool {
        mask & (1 << index) != 0
    }

    /// Number of active days in a mask.
    static func activeDayCount(_ mask: Int) -> Int {
        weekdays(from: mask).count
    }

    /// A human label like "Weekdays", "Weekends", "Every day", or "Mon, Wed, Fri".
    static func label(for mask: Int) -> String {
        let m = mask & weekdaysMask
        switch m {
        case weekdaysMask: return "Every day"
        case weekdaysMonFri: return "Weekdays"
        case weekendMask: return "Weekends"
        case 0: return "Never"
        default: return weekdays(from: m).map { weekdayShort[$0] }.joined(separator: ", ")
        }
    }

    // MARK: - Window activity

    /// The length of a window in minutes. Same-day windows (start < end) are `end - start`;
    /// a window whose end <= start is treated as crossing midnight and wraps. A zero-length
    /// window (start == end) is degenerate and counts as 0.
    static func durationMinutes(startMinute: Int, endMinute: Int) -> Int {
        ((endMinute - startMinute) % 1440 + 1440) % 1440
    }

    /// Is a window active at `date`? Honors the weekday mask and the minute range, including
    /// windows that cross midnight (e.g. 22:00–06:00), which belong to the weekday they START
    /// on — so their early-morning tail is gated by the PREVIOUS day's bit.
    static func isActive(
        startMinute: Int, endMinute: Int, weekdayMask: Int, isEnabled: Bool = true,
        at date: Date, calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled, startMinute != endMinute else { return false }
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = (comps.weekday ?? 1) - 1
        let prevWeekday = (weekday + 6) % 7

        if startMinute < endMinute {
            // Same-day window.
            return contains(weekdayMask, weekday: weekday) && minute >= startMinute && minute < endMinute
        } else {
            // Crosses midnight: evening portion on the start day, morning portion on the next.
            let eveningPortion = contains(weekdayMask, weekday: weekday) && minute >= startMinute
            let morningPortion = contains(weekdayMask, weekday: prevWeekday) && minute < endMinute
            return eveningPortion || morningPortion
        }
    }

    // MARK: - Weekly usage report

    /// An honest, non-punitive weekly summary of the user's own restriction activity, built
    /// purely from the persisted config + override log. No Screen Time usage numbers (those
    /// require a separate device-only report extension) — this reports what WE know: how much
    /// time was scheduled as restricted, and when/why the user reached past their own limits.
    struct WeeklyUsageReport: Equatable {
        var enabledWindowCount: Int = 0
        var enabledBudgetCount: Int = 0
        /// Total minutes per week the enabled windows cover (duration × active weekdays).
        var scheduledRestrictedMinutesPerWeek: Int = 0
        var overrideCount: Int = 0
        var totalOverrideMinutes: Int = 0
        /// Reason → how many overrides cited it, in the last 7 days.
        var overridesByReason: [String: Int] = [:]

        /// Hours/minutes label for the scheduled restricted time.
        var scheduledRestrictedLabel: String {
            let h = scheduledRestrictedMinutesPerWeek / 60
            let m = scheduledRestrictedMinutesPerWeek % 60
            if h == 0 { return "\(m)m" }
            if m == 0 { return "\(h)h" }
            return "\(h)h \(m)m"
        }

        /// The most-cited override reason, if any.
        var topReason: String? {
            overridesByReason.max { a, b in
                a.value != b.value ? a.value < b.value : a.key > b.key
            }?.key
        }
    }

    /// One input row for the report's window aggregation (decoupled from the @Model so the pure
    /// function is trivially testable).
    struct WindowSummary {
        let startMinute: Int
        let endMinute: Int
        let weekdayMask: Int
        let isEnabled: Bool
    }

    /// One input row for the override aggregation.
    struct OverrideSummary {
        let timestamp: Date
        let reason: String
        let minutesGranted: Int
    }

    static func weeklyReport(
        windows: [WindowSummary],
        enabledBudgetCount: Int,
        overrides: [OverrideSummary],
        now: Date = .now
    ) -> WeeklyUsageReport {
        let enabledWindows = windows.filter { $0.isEnabled }
        let scheduledMinutes = enabledWindows.reduce(0) { total, w in
            total + durationMinutes(startMinute: w.startMinute, endMinute: w.endMinute) * activeDayCount(w.weekdayMask)
        }

        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = overrides.filter { $0.timestamp >= weekAgo && $0.timestamp <= now }
        var byReason: [String: Int] = [:]
        for o in recent {
            let key = o.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = key.isEmpty ? "No reason given" : key
            byReason[normalized, default: 0] += 1
        }

        return WeeklyUsageReport(
            enabledWindowCount: enabledWindows.count,
            enabledBudgetCount: enabledBudgetCount,
            scheduledRestrictedMinutesPerWeek: scheduledMinutes,
            overrideCount: recent.count,
            totalOverrideMinutes: recent.reduce(0) { $0 + $1.minutesGranted },
            overridesByReason: byReason
        )
    }
}
