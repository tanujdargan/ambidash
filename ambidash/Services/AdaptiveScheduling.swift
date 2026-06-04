// ambidash/Services/AdaptiveScheduling.swift
//
// v5 feat/v5-adaptive-scheduling — the shared value types for ambidash's "make the day feel human"
// layer. When plans go sideways (missed blocks, a sudden meeting, a rough night's sleep, a
// recurring drift), the app offers a gentle, concrete adjustment — never guilt. The empathetic
// detection logic lives in DisruptionService+Adaptive and PatternCheckInService+Adaptive (so it
// literally extends those services); these are the in-memory results they produce. Pure value
// types — no SwiftData/SwiftUI — so all of it is unit-testable.
import Foundation

/// One humane, tappable choice on an adaptive suggestion. `isPrimary` marks the "adjust to
/// reality" option; the secondary is always a gentle, no-pressure alternative.
struct AdaptiveOption: Equatable, Identifiable {
    let id: String
    let label: String
    let isPrimary: Bool

    init(id: String, label: String, isPrimary: Bool = false) {
        self.id = id
        self.label = label
        self.isPrimary = isPrimary
    }
}

/// A single empathetic suggestion to surface when the day needs adapting. Held in memory by the
/// UI until the user taps an option — nothing is mutated until they choose, so it's fully
/// reversible. `id` is stable per kind so a dismissed suggestion doesn't re-key mid-session.
struct AdaptiveSuggestion: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case healthLighten      // rough sleep → offer a lighter day
        case carryForward       // yesterday's unfinished → still important, or let go?
        case recurringIssue     // a week-long drift → adjust the target OR the routine
        case missedReschedule   // missed blocks → propose new times, no guilt
    }

    let kind: Kind
    /// Warm headline — an observation, never a verdict.
    let title: String
    /// The supportive body explaining what we noticed and why we're offering this.
    let body: String
    /// SF Symbol for the card.
    let symbol: String
    /// The humane choices (typically an adjust-to-reality primary + a gentle secondary).
    let options: [AdaptiveOption]

    var id: String { kind.rawValue }
}

enum AdaptiveScheduling {
    /// Add `minutes` to an "HH:mm" clock string, clamped within a day. Used to propose a slightly
    /// later wake target, etc. Returns the input unchanged if it can't be parsed.
    static func clockByAdding(minutes: Int, to clock: String) -> String {
        guard let base = DailyTimeline.minutes(from: clock) else { return clock }
        let m = ((base + minutes) % 1440 + 1440) % 1440
        return DailyTimeline.Entry.format(m)
    }
}
