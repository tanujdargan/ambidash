import Foundation

/// The taxonomy types shared by Board / BoardComponent / ComponentRegistry. Kept
/// in the model layer (no SwiftUI import) so both targets compile them. All are
/// `String`-backed so they round-trip through the additive raw-string columns and
/// resolve with `.unknown` / sensible fallbacks.

// MARK: - ComponentKind

/// The identity of a board block. New surfaces are ADDITIVE cases here — because
/// `BoardComponent.kindRaw` is a String, an older client that doesn't know a new
/// case simply resolves it to `.unknown` and renders the `UnavailableComponentCard`.
enum ComponentKind: String, CaseIterable, Codable, Hashable {
    case compositeScore
    case vitalsGrid
    case sparklineHistory
    case latestGoals
    case todayNarrow
    case mentorCard
    case identityLine
    case reflectionPrompt
    case streaks
    /// Design principle #3 — TODAY as a vertical, duration-sized block timeline
    /// (fixed anchors / routines / goal-work woven into one column). Current block
    /// highlighted with a live remaining-time countdown; past blocks fade via the
    /// non-punitive `deferred` token (never red); the next block is emphasized.
    case dailyTimeline
    /// Design principle #4 — the universal capture inbox. Shows recent UNPROCESSED
    /// thoughts the user dumped (uncategorized, <2s) with one-tap gentle triage
    /// (promote → goal/today task, archive, drop). Never a backlog count, never a
    /// red "unprocessed" badge.
    case captureInbox
    /// Design principle #6 — a one-tap ENERGY / spoons check-in (1–5). Non-punitive:
    /// a low reading is information, never failure. Feeds the on-device learning /
    /// re-prioritization layer.
    case energyCheckin
    /// Build-order #8 — gentle PATTERN check-ins. Reads the on-device LearnedProfile
    /// (real-vs-target wake/sleep, adherence-by-hour, duration deltas) and surfaces a
    /// persistent drift as an OFFER, never a verdict ("you've been waking ~8:30 — move
    /// the plan, or keep your target?"). Accepting edits UserPreferences. Confidence-
    /// gated + non-punitive; renders nothing when there's no pattern worth surfacing.
    case patternCheckIn
    /// CLOSING RITUAL — the gentle end-of-day flow (Sunsama's most-loved mechanic,
    /// made non-punitive). Celebrates what you ACTUALLY did today (partials count,
    /// deferrals roll forward), takes an optional one-line "what felt good / hard",
    /// and lets you pick TOMORROW's ONE most-important thing — which the next
    /// plan-generation pins as the protected first block. Never punitive, never a
    /// chore.
    case closingRitual
    /// Fallback for raw values this build doesn't understand.
    case unknown
}

// MARK: - ComponentCategory

/// Grouping used by the (future) add-menu to bucket components into sections.
enum ComponentCategory: String, CaseIterable, Codable, Hashable {
    case overview
    case metrics
    case goals
    case daily
    case insights
    case reflection

    var title: String {
        switch self {
        case .overview: "Overview"
        case .metrics: "Metrics"
        case .goals: "Goals"
        case .daily: "Daily"
        case .insights: "Insights"
        case .reflection: "Reflection"
        }
    }
}

// MARK: - BoardSection

/// 1.5-D layout bands (ordered, not a free x/y canvas). `top` is a single-column
/// hero band; `body` is the main flowing column; `focus` is a reserved do-now zone.
enum BoardSection: String, CaseIterable, Codable, Hashable {
    case top
    case body
    case focus

    /// Render order of the bands within the board.
    var order: Int {
        switch self {
        case .top: 0
        case .body: 1
        case .focus: 2
        }
    }
}

// MARK: - CardSize

/// Rendered footprint of a component. `full` spans the column; the others tune
/// vertical/inline prominence within the body band.
enum CardSize: String, CaseIterable, Codable, Hashable {
    case small
    case medium
    case large
    case full
}
