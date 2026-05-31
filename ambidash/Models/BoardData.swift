import Foundation

/// A plain value struct (NOT a @Model) carrying every dashboard-level computed
/// value ONCE per render cycle. The board computes this a single time and injects
/// it into every component renderer, so no renderer issues its own @Query and all
/// components read a consistent snapshot of the data.
///
/// This is the seam that keeps the LazyVStack of components cheap: shared compute
/// happens at the board level, renderers are pure functions of `BoardData`.
struct BoardData {
    let profile: UserProfile?
    let todaySnapshot: IntegrationSnapshot?
    let yesterdaySnapshot: IntegrationSnapshot?
    /// Active goals, priority-ordered (mirrors DashboardView.activeGoals).
    let activeGoals: [Goal]
    /// The three most-recently-active goals (recency of progress activity).
    let latestGoals: [Goal]
    let todayPlan: DailyPlan?
    let dimensionScores: [LifeDimension: Int]
    let compositeScore: Int
    let streakSummary: StreakService.StreakSummary
    /// Real 14-day composite history terminating at the live composite.
    let compositeHistory: [Double]
    /// Lowest-scoring dimension, used to pick the identity-line copy.
    let lowestDimension: LifeDimension?

    /// Contextual "you are becoming…" line, derived from the lowest dimension.
    /// Hoisted out of DashboardView so the identityLine component can render it.
    var identityText: String {
        switch lowestDimension {
        case .body: return "someone who treats their body as the instrument it is."
        case .mind: return "someone whose mind is sharper than their impulses."
        case .craft: return "someone who does the work, not just plans it."
        case .people: return "someone whose attention belongs to the people in front of them."
        case .wealth: return "someone whose freedom isn't borrowed."
        case .adventure: return "someone who lives, not just optimizes."
        case nil: return "someone who finishes what they start."
        }
    }
}
