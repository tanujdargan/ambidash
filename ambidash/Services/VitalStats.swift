// ambidash/Services/VitalStats.swift
//
// v5 feat/v5-custom-vitals — PURE statistics over a vital's logged history (today's total, latest
// value, weekly average, progress toward target, days logged, and a current streak). No
// SwiftData/SwiftUI dependency, so it's fully unit-testable; the views pass in plain points.
import Foundation

enum VitalStats {

    /// A single logged value (decoupled from the @Model so the math is trivially testable).
    struct Point: Equatable {
        let value: Double
        let date: Date
    }

    struct Summary: Equatable {
        var todayTotal: Double = 0
        var latest: Double? = nil
        /// Average of per-day totals over the last 7 days, across days that had at least one entry.
        var weekAverage: Double? = nil
        /// Today's total as a fraction of the target (0 when no target).
        var progress: Double = 0
        var daysLoggedThisWeek: Int = 0
        /// Consecutive days (ending today or yesterday) with at least one entry.
        var currentStreak: Int = 0

        var progressPercent: Int { Int((progress * 100).rounded()) }
    }

    static func summary(entries: [Point], target: Double, now: Date = .now, calendar: Calendar = .current) -> Summary {
        guard !entries.isEmpty else {
            return Summary(todayTotal: 0, latest: nil, weekAverage: nil, progress: 0, daysLoggedThisWeek: 0, currentStreak: 0)
        }

        let todayStart = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        let todayTotal = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }.reduce(0) { $0 + $1.value }
        let latest = entries.max(by: { $0.date < $1.date })?.value

        // Per-day totals over the last 7 days (today and the 6 before).
        let recent = entries.filter { $0.date >= weekAgo && $0.date <= now }
        var dayTotals: [Date: Double] = [:]
        for p in recent {
            let key = calendar.startOfDay(for: p.date)
            dayTotals[key, default: 0] += p.value
        }
        let weekAverage = dayTotals.isEmpty ? nil : dayTotals.values.reduce(0, +) / Double(dayTotals.count)

        let progress = target > 0 ? min(max(todayTotal / target, 0), 1) : 0

        return Summary(
            todayTotal: todayTotal,
            latest: latest,
            weekAverage: weekAverage,
            progress: progress,
            daysLoggedThisWeek: dayTotals.count,
            currentStreak: currentStreak(entries: entries, now: now, calendar: calendar)
        )
    }

    /// Consecutive days with at least one entry, anchored at today (or yesterday if today has none
    /// yet — a grace so an un-logged morning doesn't read as a broken streak). Returns 0 when the
    /// most recent entry is older than yesterday.
    static func currentStreak(entries: [Point], now: Date = .now, calendar: Calendar = .current) -> Int {
        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !loggedDays.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var anchor: Date
        if loggedDays.contains(today) { anchor = today }
        else if loggedDays.contains(yesterday) { anchor = yesterday }
        else { return 0 }

        var streak = 0
        var cursor = anchor
        while loggedDays.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    /// Per-day totals for the last `days` days, oldest → newest, for a sparkline. Days with no
    /// entry are 0.
    static func dailyTotals(entries: [Point], days: Int = 7, now: Date = .now, calendar: Calendar = .current) -> [Double] {
        let todayStart = calendar.startOfDay(for: now)
        return (0..<days).reversed().map { offset in
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
            return entries
                .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
                .reduce(0) { $0 + $1.value }
        }
    }
}
