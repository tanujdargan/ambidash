import Testing
import Foundation
@testable import ambidash

// Phase 1 — pure retention cores: ConsistencyMetric (non-punitive headline + repair),
// PlanRanking (the one ranking engine), and the JITAINudge Thompson bandit + FrequencyCaps.
// All pure; the bandit is driven by a seeded RNG so selection is deterministic.

private let cal = Calendar(identifier: .gregorian)
private func daysAgo(_ n: Int, from now: Date) -> Date {
    cal.date(byAdding: .day, value: -n, to: now)!
}

/// Deterministic SplitMix64 for the bandit tests.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - ConsistencyMetric

@Test func consistencyIsFractionOfExpectedCadence() {
    let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 12))!
    // 3×/week over 28 days → expected 12 distinct days.
    let twelve = (0..<12).map { daysAgo($0, from: now) }
    #expect(ConsistencyMetric.consistency(loggedDates: twelve, timesPerWeek: 3, windowDays: 28, now: now, calendar: cal) == 1.0)
    let six = (0..<6).map { daysAgo($0, from: now) }
    #expect(ConsistencyMetric.consistency(loggedDates: six, timesPerWeek: 3, windowDays: 28, now: now, calendar: cal) == 0.5)
    // Over-delivery caps at 1.0; old dates outside the window don't count.
    let many = (0..<40).map { daysAgo($0, from: now) }
    #expect(ConsistencyMetric.consistency(loggedDates: many, timesPerWeek: 3, windowDays: 28, now: now, calendar: cal) == 1.0)
}

@Test func consistencyBandsAreWarm() {
    #expect(ConsistencyMetric.band(0.9) == "Rock solid")
    #expect(ConsistencyMetric.band(0.7) == "Strong")
    #expect(ConsistencyMetric.band(0.4) == "Building")
    #expect(ConsistencyMetric.band(0.1) == "Just starting")
}

@Test func streakRepairWithinWindowKeepsTheRunElseResets() {
    // cadence 3/wk → allowedGap = ceil(7/3)+1 = 4; repair window +2 → mendable up to 6.
    #expect(ConsistencyMetric.canRepair(daysSinceLastActive: 5, timesPerWeek: 3) == true)
    #expect(ConsistencyMetric.canRepair(daysSinceLastActive: 4, timesPerWeek: 3) == false) // still on schedule
    #expect(ConsistencyMetric.canRepair(daysSinceLastActive: 7, timesPerWeek: 3) == false) // past repair window
    #expect(ConsistencyMetric.repairedCount(currentCount: 10, daysSinceLastActive: 5, timesPerWeek: 3) == 11)
    #expect(ConsistencyMetric.repairedCount(currentCount: 10, daysSinceLastActive: 9, timesPerWeek: 3) == 1)
}

// MARK: - PlanRanking

private func cand(priority: Int = 5, deadline: Int? = nil, goal: Bool = false,
                  stale: Int = 0, load: Int = 3) -> PlanRanking.Candidate {
    .init(id: UUID(), priority: priority, daysUntilDeadline: deadline,
          hasGoalLink: goal, daysSinceProgress: stale, cognitiveLoad: load)
}

@Test func rankingPrioritizesUrgencyPriorityLinkageStaleness() {
    #expect(PlanRanking.score(cand(deadline: 0)) > PlanRanking.score(cand(deadline: 13)))   // urgency
    #expect(PlanRanking.score(cand(priority: 1)) > PlanRanking.score(cand(priority: 9)))     // priority
    #expect(PlanRanking.score(cand(goal: true)) > PlanRanking.score(cand(goal: false)))      // linkage
    #expect(PlanRanking.score(cand(stale: 7)) > PlanRanking.score(cand(stale: 0)))           // staleness
}

@Test func rankOrdersHighToLowDeterministically() {
    let overdue = cand(priority: 5, deadline: -1)
    let routine = cand(priority: 8, deadline: nil)
    let ranked = PlanRanking.rank([routine, overdue])
    #expect(ranked.first == overdue)   // the overdue, deadline-urgent item leads
}

@Test func energyBandByCognitiveLoad() {
    #expect(PlanRanking.band(forCognitiveLoad: 5) == .peak)
    #expect(PlanRanking.band(forCognitiveLoad: 3) == .steady)
    #expect(PlanRanking.band(forCognitiveLoad: 1) == .low)
}

// MARK: - JITAINudge bandit + caps

@Test func banditArmRewardUpdatesPosterior() {
    var arm = JITAINudge.Arm()
    #expect(arm.mean == 0.5)                 // uniform prior
    arm.reward(success: true)
    #expect(arm.alpha == 2 && arm.beta == 1)
    arm.reward(success: false)
    #expect(arm.alpha == 2 && arm.beta == 2)
}

@Test func banditThompsonPicksTheArmWithStrongerEvidence() {
    let weak = JITAINudge.Arm(alpha: 1, beta: 50)     // ~0.02 engagement
    let strong = JITAINudge.Arm(alpha: 50, beta: 1)   // ~0.98 engagement
    // Across several seeds, Thompson sampling should pick the strong arm (index 1).
    for seed: UInt64 in [1, 7, 42, 1000] {
        var rng = SeededRNG(seed: seed)
        #expect(JITAINudge.select([weak, strong], using: &rng) == 1)
    }
}

@Test func frequencyCapsBlockOveruseAndAllowDoNothing() {
    let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 12))!
    let caps = FrequencyCaps(perDay: 3, perCategoryPerDay: 1)
    var fires: [(category: String, at: Date)] = []
    #expect(caps.canFire(category: "goal", recentFires: fires, now: now, calendar: cal) == true)
    fires.append(("goal", now))
    // Same category again today → blocked by per-category cap.
    #expect(caps.canFire(category: "goal", recentFires: fires, now: now, calendar: cal) == false)
    // A different category still allowed (under per-day cap).
    #expect(caps.canFire(category: "money", recentFires: fires, now: now, calendar: cal) == true)
    // Fill the per-day cap → everything blocked (the "do nothing" path).
    fires.append(("money", now)); fires.append(("health", now))
    #expect(caps.canFire(category: "reflect", recentFires: fires, now: now, calendar: cal) == false)
}

// MARK: - MonetizationConfig

@Test func monetizationTierResolvesByPrecedence() {
    typealias M = MonetizationConfig
    #expect(M.tier(hasActiveSubscription: true, isLifetimeFounder: true, hasBYOKKey: true, trialActive: true) == .founder)
    #expect(M.tier(hasActiveSubscription: true, isLifetimeFounder: false, hasBYOKKey: true, trialActive: true) == .premium)
    #expect(M.tier(hasActiveSubscription: false, isLifetimeFounder: false, hasBYOKKey: true, trialActive: true) == .trial)
    #expect(M.tier(hasActiveSubscription: false, isLifetimeFounder: false, hasBYOKKey: true, trialActive: false) == .byok)
    #expect(M.tier(hasActiveSubscription: false, isLifetimeFounder: false, hasBYOKKey: false, trialActive: false) == .free)
}

@Test func monetizationOnlyFreeTierIsGatedAndStudentPriceDiscounts() {
    #expect(MonetizationConfig.unlocksAI(.byok) == true)
    #expect(MonetizationConfig.unlocksAI(.free) == false)
    #expect(MonetizationConfig.studentPrice(39.99) == 23.99)            // 40% off, to cents
    #expect(MonetizationConfig.founderSeatsAvailable(claimed: 499) == true)
    #expect(MonetizationConfig.founderSeatsAvailable(claimed: 500) == false)
}
