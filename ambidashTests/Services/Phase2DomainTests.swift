import Testing
import Foundation
@testable import ambidash

// Phase 2 — the domain-module framework. Verifies the WealthDomainModule honours the
// five-part contract and the DomainRegistry rolls modules up into the one score / one
// plan / one nudge layer. All pure.

private func mg(_ pct: Double, priority: Int = 5, deadline: Int? = nil, stale: Int = 0) -> WealthDomainModule.MoneyGoalSnapshot {
    .init(title: "g", percentComplete: pct, daysUntilDeadline: deadline, priority: priority, daysSinceProgress: stale)
}

/// A trivial second module so registry roll-up across dimensions is exercised.
private struct StubHealthModule: DomainModule {
    let score: Int
    var id: String { "health" }
    var displayName: String { "Body" }
    var dimension: LifeDimension { .body }
    func dimensionScore(now: Date) -> Int { score }
    func planCandidates(now: Date) -> [PlanRanking.Candidate] { [] }
}

// MARK: - WealthDomainModule (contract proof)

@Test func wealthModuleScoresAverageProgressAndIsNeutralWhenEmpty() {
    let m = WealthDomainModule(goals: [mg(0.5), mg(1.0)])
    #expect(m.dimensionScore(now: .now) == 75)          // (50 + 100) / 2
    #expect(WealthDomainModule().dimensionScore(now: .now) == 50)   // empty → neutral
    #expect(m.dimension == .wealth)
    #expect(m.lensRoute == "ambidash://money")          // one lens
}

@Test func wealthModuleEmitsPlanCandidatesAndGatedNudges() {
    let m = WealthDomainModule(goals: [mg(0.2, priority: 2, deadline: 3), mg(0.9)], pendingReviewCount: 3)
    let cands = m.planCandidates(now: .now)
    #expect(cands.count == 2)
    #expect(cands.contains { $0.priority == 2 && $0.daysUntilDeadline == 3 && $0.hasGoalLink })
    let nudges = m.nudges(now: .now)
    #expect(nudges.count == 1)
    #expect(nudges.first?.category == "wealth")          // registers under its own cap bucket
    // No pending reviews → no nudge (never nags).
    #expect(WealthDomainModule(goals: [mg(0.5)]).nudges(now: .now).isEmpty)
}

// MARK: - DomainRegistry roll-up

@Test func registryRollsUpScorePlanAndNudges() {
    let wealth = WealthDomainModule(goals: [mg(0.8, priority: 1, deadline: 0)], pendingReviewCount: 2)
    let health = StubHealthModule(score: 60)
    let reg = DomainRegistry(modules: [wealth, health])

    let dims = reg.dimensionScores(now: .now)
    #expect(dims[.wealth] == 80)
    #expect(dims[.body] == 60)
    // composite via the same PulseScoreCalculator the app uses (averages present dims;
    // absent dims default to neutral 50 inside pulse).
    #expect(reg.compositeScore(now: .now) > 0)

    // One plan: candidates from all domains, ranked by the one engine.
    #expect(reg.planCandidates(now: .now).count == 1)
    // One nudge layer: aggregated across domains.
    #expect(reg.nudges(now: .now).count == 1)
    #expect(reg.nudges(now: .now).first?.category == "wealth")
}
