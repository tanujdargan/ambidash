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
    /// v4 — a completion/progress surface: how many of today's blocks are done,
    /// with a progress ring. The "dopamine hit" of marking things complete.
    case todayProgress
    /// v4 — a 1–7 day look-ahead: upcoming days with their dated milestone
    /// deadlines, so "midterm in 2 days" is visible before it arrives.
    case weekAhead
    /// v4 — a "sticky note" surface: pinned (isSticky) goals kept always-visible
    /// but glanceable, for must-not-forget goals that aren't top priority.
    case stickyGoals
    /// v4 — DYNAMIC categories derived from the user's goals (grouped by domain),
    /// with goal + subgoal counts. Categories emerge from what you're working on.
    case categories
    /// v4 — a contextual wake-adjust nudge: when actual wake drifts late of the
    /// target, gently offer to right-size the goal or pull the wind-down earlier.
    case wakeAdjust
    /// v4 — goal-tied vitals: per-goal status (on track / needs time) straight up,
    /// so the dashboard vitals reflect the actual goals, not abstract scores.
    case goalVitals
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
    /// FOCUS SESSION — a calm, visible countdown timer for a chosen duration or the
    /// CURRENT timeline block. Start/pause/stop with gentle (never guilt) completion,
    /// an optional looping soundscape (AVAudioSession .ambient — mixes with the user's
    /// audio, respects the silent switch), and a LOCAL "body-double" presence
    /// affordance (a calm "focusing with you" companion line + an optional on-device
    /// AI check-in, gated; no networking required for the timer itself). The session
    /// is ephemeral (@State) — no new @Model, no CloudKit impact. A finished session
    /// against a block may fold an inferred ActualEvent into the wins/learning loop.
    case focusSession
    /// WINS WALL — evidence of what you actually DID, framed as "look what you did".
    /// Derives recent wins from existing data (completed/partial ActualEvents +
    /// lifecycle .done/.partial PlannedActions) over a rolling window via WinsService —
    /// no new @Model, no CloudKit migration. Partials COUNT; nothing is ever framed as a
    /// deficit or a miss-count. A preview shows the top recent wins + a warm "X this
    /// week", and a gentle weekly "your week in wins" review surface (WinsWeekSheet)
    /// groups the week's wins by day.
    case winsWall
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

    /// Fraction of the available board width this size occupies. Drives a VISIBLE
    /// resize: a `small` card sits at half width, `full` spans the band. The band is a
    /// single-column LazyVStack, so smaller sizes leading-align and leave breathing
    /// room on the right rather than re-flowing into columns (kept intentionally
    /// simple + predictable for Swift 6 / CloudKit-safe layout).
    var widthFraction: CGFloat {
        switch self {
        case .small: 0.55
        case .medium: 0.72
        case .large: 0.88
        case .full: 1.0
        }
    }
}
