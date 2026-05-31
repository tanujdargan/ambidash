// ambidash/Services/RestBankService.swift
import Foundation

/// REST-DAY BANK — the pure, non-punitive logic for EARNING rest days through
/// consistency and SPENDING them guilt-free. Rest is framed as PERMISSION the user has
/// already earned, never as an obligation or a cost. Spending a banked day marks the
/// day rest (streak-safe — a rest day never breaks a streak) and is fully reversible in
/// the same day.
///
/// All state lives on the already-registered `UserPreferences` (additive scalars), so
/// there is NOTHING new to register in either ModelContainer and ZERO CloudKit
/// migration. No SwiftUI import → compiles into BOTH targets. The service mutates the
/// passed `UserPreferences` in place; the CALLER owns `modelContext.save()`.
enum RestBankService {

    /// How many consistent days earn one banked rest day. A gentle cadence: a week of
    /// keeping any streak alive grants a day off. Tunable; deliberately generous.
    static let daysPerEarnedRest = 7

    /// Whether the bank has at least one rest day available to spend today.
    static func canSpend(_ prefs: UserPreferences) -> Bool {
        prefs.bankedRestDays > 0 && !spentToday(prefs)
    }

    /// True when a banked rest day was already spent for today (idempotency guard so a
    /// re-tap can't drain the bank).
    static func spentToday(_ prefs: UserPreferences, calendar: Calendar = .current) -> Bool {
        guard let last = prefs.lastRestDaySpent else { return false }
        return calendar.isDateInToday(last)
    }

    /// Spend one banked rest day for TODAY. Decrements the balance, bumps the spent
    /// total, and stamps `lastRestDaySpent`. Idempotent per day and a no-op when the bank
    /// is empty. Returns true when a day was actually spent (so the caller can show the
    /// kind confirmation + mark the day rest). The caller persists.
    @discardableResult
    static func spend(_ prefs: UserPreferences, calendar: Calendar = .current, now: Date = .now) -> Bool {
        guard prefs.bankedRestDays > 0, !spentToday(prefs, calendar: calendar) else { return false }
        prefs.bankedRestDays -= 1
        prefs.restDaysSpentTotal += 1
        prefs.lastRestDaySpent = calendar.startOfDay(for: now)
        return true
    }

    /// Refund the rest day spent today (reverses `spend` within the same day — the user
    /// changed their mind). No-op if nothing was spent today. Caller persists.
    @discardableResult
    static func refundToday(_ prefs: UserPreferences, calendar: Calendar = .current) -> Bool {
        guard spentToday(prefs, calendar: calendar) else { return false }
        prefs.bankedRestDays += 1
        prefs.restDaysSpentTotal = max(0, prefs.restDaysSpentTotal - 1)
        prefs.lastRestDaySpent = nil
        return true
    }

    /// Evaluate consistency and grant earned rest days, at most once per day. Earns one
    /// rest day per `daysPerEarnedRest` of the longest live streak that hasn't already
    /// been credited. Kept deliberately simple + generous: the goal is to make rest feel
    /// *deserved*, not to gate it tightly. Returns the number granted this call (0 most
    /// days). The caller persists.
    ///
    /// `longestLiveStreak` is the best current streak count across the user's goals
    /// (from `StreakService.summary(...).longestCurrentStreak`). We grant up to the
    /// number of full `daysPerEarnedRest` blocks it represents, minus what's already been
    /// earned historically — so a 14-day streak yields at most 2 banked days over time,
    /// never a flood.
    @discardableResult
    static func evaluateEarn(
        _ prefs: UserPreferences,
        longestLiveStreak: Int,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        // At most one evaluation per day (cheap + avoids double-credit on re-render).
        if let last = prefs.lastRestEarnCheck, calendar.isDateInToday(last) { return 0 }
        prefs.lastRestEarnCheck = calendar.startOfDay(for: now)

        guard longestLiveStreak >= daysPerEarnedRest else { return 0 }
        let deserved = longestLiveStreak / daysPerEarnedRest
        let granted = max(0, deserved - prefs.restDaysEarnedTotal)
        guard granted > 0 else { return 0 }
        prefs.restDaysEarnedTotal += granted
        prefs.bankedRestDays += granted
        return granted
    }

    /// A warm, permission-framed chip label for the bank balance.
    static func chipLabel(_ prefs: UserPreferences) -> String {
        switch prefs.bankedRestDays {
        case 0: return "Rest bank — earned by showing up"
        case 1: return "1 rest day banked — yours to use"
        default: return "\(prefs.bankedRestDays) rest days banked — yours to use"
        }
    }
}
