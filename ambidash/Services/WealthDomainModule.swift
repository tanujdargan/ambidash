import Foundation

// Phase 2 — the first concrete DomainModule, proving the contract end-to-end (and
// pre-staging Phase 3's finance). It consumes normalized money-goal snapshots (signals
// in), contributes the `wealth` dimension to the one score, drops "money admin"
// candidates into the one plan, exposes one money lens, and registers gentle nudges.
//
// Pure value types — no SwiftData here — so the whole module is unit-testable. Phase 3
// fills these snapshots from real Account/Transaction/MoneyGoal models.
struct WealthDomainModule: DomainModule {

    /// A normalized money-goal signal (Phase 3 derives these from MoneyGoal/Goal records).
    struct MoneyGoalSnapshot: Equatable {
        let title: String
        /// 0…1 progress toward the goal (e.g. saved/target).
        let percentComplete: Double
        let daysUntilDeadline: Int?
        let priority: Int
        let daysSinceProgress: Int
    }

    let goals: [MoneyGoalSnapshot]
    /// Count of subscriptions / charges awaiting a quick review (a gentle plan item).
    let pendingReviewCount: Int

    init(goals: [MoneyGoalSnapshot] = [], pendingReviewCount: Int = 0) {
        self.goals = goals
        self.pendingReviewCount = pendingReviewCount
    }

    var id: String { "wealth" }
    var displayName: String { "Money" }
    var dimension: LifeDimension { .wealth }
    var lensRoute: String? { "ambidash://money" }

    /// Average money-goal progress as a 0…100 dimension score; 50 (neutral) when there's
    /// no money data yet — never punishes an empty domain.
    func dimensionScore(now: Date) -> Int {
        guard !goals.isEmpty else { return 50 }
        let avg = goals.map(\.percentComplete).reduce(0, +) / Double(goals.count)
        return Int((min(max(avg, 0), 1) * 100).rounded())
    }

    /// Each money goal becomes a capacity-band candidate in the one plan (light cognitive
    /// load — money admin is not deep work).
    func planCandidates(now: Date) -> [PlanRanking.Candidate] {
        goals.map { g in
            PlanRanking.Candidate(
                id: UUID(),
                priority: g.priority,
                daysUntilDeadline: g.daysUntilDeadline,
                hasGoalLink: true,
                daysSinceProgress: g.daysSinceProgress,
                cognitiveLoad: 2
            )
        }
    }

    /// A gentle "review N subscriptions" nudge when there's something to review — never a
    /// nagging bills tab; registered with the one JITAI layer under the "wealth" cap bucket.
    func nudges(now: Date) -> [DomainNudge] {
        guard pendingReviewCount > 0 else { return [] }
        let word = pendingReviewCount == 1 ? "subscription" : "subscriptions"
        return [DomainNudge(
            category: id,
            title: "A quick money win",
            body: "Review \(pendingReviewCount) \(word) when you have a low-energy minute.",
            preferredMinuteOfDay: nil
        )]
    }
}
