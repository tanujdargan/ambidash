import Foundation

/// Formats the weekly adherence of a habitual goal as human-readable strings.
///
/// Lives in Utilities (not a View file) because it is pure logic over the shared
/// `Goal` model and is consumed by the cross-platform `MentorPromptBuilder`
/// service as well as the iOS goal views. Keeping it here lets both the iOS app
/// and the macOS app compile against it.
enum AdherenceFormat {
    /// Count of progress logs recorded in the current calendar week.
    static func loggedThisWeek(for goal: Goal) -> Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        return (goal.progressLogs ?? []).filter { $0.date >= weekStart }.count
    }

    /// The intended weekly cadence, defaulting to once if none was set.
    static func target(for goal: Goal) -> Int {
        max(goal.timesPerWeek, 1)
    }

    /// e.g. "3 of 4 this week".
    static func fraction(for goal: Goal) -> String {
        "\(loggedThisWeek(for: goal)) of \(target(for: goal)) this week"
    }

    /// Compact form for dense rows, e.g. "3/4 this wk".
    static func compact(for goal: Goal) -> String {
        "\(loggedThisWeek(for: goal))/\(target(for: goal)) this wk"
    }
}
