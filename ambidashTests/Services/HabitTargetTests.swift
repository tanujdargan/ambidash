import Testing
import Foundation
@testable import ambidash

// Phase 0 — coverage for the measurable-target + habit-cadence logic the plan flags
// as "model-complete but thin/under-tested". All pure (in-memory Goal/Streak, no
// container): percentComplete, TargetMath pace/variance, PlanGenerator.quantitativeTarget,
// and Streak.recordActivity(forCadence:) — the non-punitive cadence-grace differentiator.

private func measurableGoal(baseline: Double, target: Double, current: Double,
                            direction: MetricDirection = .increase, unit: String = "km") -> Goal {
    let g = Goal(title: "G", domain: .body, priority: 1)
    g.metricEnabled = true
    g.baselineValue = baseline
    g.targetValue = target
    g.currentValue = current
    g.direction = direction
    g.unit = unit
    return g
}

// MARK: - Goal.percentComplete

@Test func percentCompleteIncreaseAndDecrease() {
    #expect(measurableGoal(baseline: 0, target: 50, current: 25).percentComplete == 0.5)
    // decrease: from 100 toward 0, currently 75 → 25% of the way down
    let down = measurableGoal(baseline: 100, target: 0, current: 75, direction: .decrease)
    #expect(down.percentComplete == 0.25)
    // no metric → 0
    let g = Goal(title: "x", domain: .mind, priority: 1)
    #expect(g.percentComplete == 0)
}

// MARK: - TargetMath pace + variance

@Test func varianceBehindWhenLaggingExpectedPace() {
    // 60d into a 90d (.now) horizon → expected ≈ 66.7; current 10 → behind.
    let g = measurableGoal(baseline: 0, target: 100, current: 10)
    g.horizon = .now
    g.createdAt = Calendar.current.date(byAdding: .day, value: -60, to: .now)!
    #expect(TargetMath.variance(g) == .behind)
    #expect(TargetMath.expectedValue(g) > 50)
}

@Test func varianceAheadWhenBeatingExpectedPace() {
    let g = measurableGoal(baseline: 0, target: 100, current: 95)
    g.horizon = .now
    g.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: .now)!  // expected ≈ 33
    #expect(TargetMath.variance(g) == .ahead)
}

@Test func varianceOnTrackForNonMeasurable() {
    let g = Goal(title: "habit", domain: .mind, priority: 1)   // no target
    #expect(TargetMath.variance(g) == .onTrack)
}

// MARK: - PlanGenerator.quantitativeTarget

@Test func quantitativeTargetForMeasurableGoalSplitsRemainingGap() {
    let g = measurableGoal(baseline: 0, target: 50, current: 0, unit: "km")
    let (amount, unit) = PlanGenerator.quantitativeTarget(for: g, durationMinutes: 30)
    #expect(amount != nil)
    #expect(amount! > 0)
    #expect(unit == "km")
}

// MARK: - Streak.recordActivity(forCadence:)  — non-punitive cadence grace

@Test func cadenceStreakAdvancesWithinAllowedGap() {
    let s = Streak()                       // init: count 0, freezes 2, lastActive = now
    s.currentCount = 4
    s.lastActiveDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    s.recordActivity(forCadence: 3)        // 3x/wk → allowedGap = ceil(7/3)+1 = 4; 1 <= 4
    #expect(s.currentCount == 5)
    #expect(s.freezesRemaining == 2)
}

@Test func cadenceStreakConsumesAFreezeWhenSlightlyOver() {
    let s = Streak()
    s.currentCount = 5
    s.freezesRemaining = 2
    s.lastActiveDate = Calendar.current.date(byAdding: .day, value: -6, to: .now)!  // 6 > gap 4
    s.recordActivity(forCadence: 3)
    #expect(s.currentCount == 6)           // kept alive via grace, not reset
    #expect(s.freezesRemaining == 1)
}

@Test func cadenceStreakResetsOnlyAfterFreezesExhausted() {
    let s = Streak()
    s.currentCount = 10
    s.freezesRemaining = 0
    s.lastActiveDate = Calendar.current.date(byAdding: .day, value: -6, to: .now)!
    s.recordActivity(forCadence: 3)
    #expect(s.currentCount == 1)           // reset to today
    #expect(s.freezesRemaining == 2)       // grace restored
}

@Test func cadenceSameDayLogIsNoOp() {
    let s = Streak()
    s.currentCount = 3
    s.lastActiveDate = .now                // already logged today
    s.recordActivity(forCadence: 3)
    #expect(s.currentCount == 3)           // unchanged
}
