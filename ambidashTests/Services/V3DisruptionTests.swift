// ambidashTests/Services/V3DisruptionTests.swift
//
// V3 regression tests for DisruptionService.buildDiff. The core invariant locked
// in here: the re-plan NEVER drops the protected "one thing" — even under the
// harshest trim (healthFlare / lowEnergy level<=2, keepBudget 0), the single
// most-important block is always kept (never .dropped). Plus cross-midnight
// now-anchoring of remainingActions, and RestBank can't-go-negative regressions.
import Testing
import Foundation
import SwiftData
@testable import ambidash

private func goalWork(_ title: String, slot: String, goalID: UUID?, duration: Int = 45) -> PlannedAction {
    let a = PlannedAction(title: title, timeSlot: slot, duration: duration, goalID: goalID, anchorType: "goal_work")
    return a
}

// MARK: - REGRESSION: the protected "one thing" is never dropped

@MainActor
@Test func buildDiffNeverDropsProtectedUnderHealthFlare() throws {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    // "now" = 08:00 on the plan's day; all blocks are still ahead.
    let now = cal.date(byAdding: .minute, value: 8 * 60, to: planDay)!

    // A high-priority goal (priority 0) so its block is the most-important.
    let topGoal = Goal(title: "Top", domain: .craft, priority: 0)
    let lowGoal = Goal(title: "Low", domain: .body, priority: 9)

    let plan = DailyPlan(date: planDay)
    let protectedBlock = goalWork("Most important", slot: "10:00", goalID: topGoal.id)
    let other1 = goalWork("Other A", slot: "11:00", goalID: lowGoal.id)
    let other2 = goalWork("Other B", slot: "13:00", goalID: lowGoal.id)
    plan.actions = [protectedBlock, other1, other2]

    let prefs = UserPreferences()

    let diff = DisruptionService.buildDiff(
        for: plan,
        trigger: .healthFlare,             // keepBudget 0 — trims everything else
        prefs: prefs,
        goals: [topGoal, lowGoal],
        now: now
    )

    #expect(diff.protectedID == protectedBlock.id)
    let protectedEntry = diff.entries.first { $0.id == protectedBlock.id }
    #expect(protectedEntry != nil)
    #expect(protectedEntry?.kind != .dropped, "The protected one thing must never be dropped")
    #expect(protectedEntry?.isProtected == true)
    // Under healthFlare every OTHER goal-work block is deferred.
    let others = diff.entries.filter { $0.id != protectedBlock.id }
    #expect(others.allSatisfy { $0.kind == .dropped })
}

@MainActor
@Test func buildDiffProtectedEntryAlwaysPresentEvenWhenLowEnergyZeroBudget() throws {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    let now = cal.date(byAdding: .minute, value: 9 * 60, to: planDay)!

    let goal = Goal(title: "G", domain: .mind, priority: 1)
    let plan = DailyPlan(date: planDay)
    let only = goalWork("Single goal work", slot: "12:00", goalID: goal.id)
    plan.actions = [only]

    let diff = DisruptionService.buildDiff(
        for: plan,
        trigger: .lowEnergy(level: 1),     // keepBudget 0
        prefs: UserPreferences(),
        goals: [goal],
        now: now
    )

    let entry = diff.protectedEntry
    #expect(entry != nil, "There must still be a protected entry surfaced")
    #expect(entry?.kind != .dropped)
    #expect(diff.entries.contains { $0.id == only.id }, "The kept one-thing must be in the diff")
}

@MainActor
@Test func buildDiffKeepsFixedAnchorsAndDoesNotDropThem() throws {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    let now = cal.date(byAdding: .minute, value: 7 * 60, to: planDay)!

    let goal = Goal(title: "G", domain: .craft, priority: 2)
    let plan = DailyPlan(date: planDay)
    let cls = PlannedAction(title: "Class", timeSlot: "10:00", duration: 90, anchorType: "fixed")
    let work = goalWork("Study", slot: "14:00", goalID: goal.id)
    plan.actions = [cls, work]

    let diff = DisruptionService.buildDiff(
        for: plan,
        trigger: .lowEnergy(level: 1),
        prefs: UserPreferences(),
        goals: [goal],
        now: now
    )

    let anchor = diff.entries.first { $0.id == cls.id }
    #expect(anchor != nil)
    #expect(anchor?.kind == .kept, "Fixed anchors are always kept, never dropped")
}

// MARK: - REGRESSION: cross-midnight remaining-actions anchoring

@MainActor
@Test func remainingActionsEmptyAfterPlanDayIsOver() throws {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    let plan = DailyPlan(date: planDay)
    let goal = Goal(title: "G", domain: .body, priority: 1)
    plan.actions = [goalWork("Evening run", slot: "20:00", goalID: goal.id)]

    // It's 01:00 the NEXT day — the whole plan is behind us.
    let nextDay = cal.date(byAdding: .day, value: 1, to: planDay)!
    let now = cal.date(byAdding: .minute, value: 60, to: nextDay)!

    let remaining = DisruptionService.remainingActions(in: plan, now: now)
    #expect(remaining.isEmpty, "After midnight, an evening plan has nothing remaining (not mis-read as future)")
}

@MainActor
@Test func remainingActionsExcludesSettledAndPastBlocks() throws {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    let now = cal.date(byAdding: .minute, value: 12 * 60, to: planDay)! // noon
    let goal = Goal(title: "G", domain: .body, priority: 1)

    let plan = DailyPlan(date: planDay)
    let past = goalWork("Morning", slot: "08:00", goalID: goal.id, duration: 30) // ends 08:30 < noon
    let future = goalWork("Afternoon", slot: "15:00", goalID: goal.id)
    let doneFuture = goalWork("Done already", slot: "16:00", goalID: goal.id)
    doneFuture.applyLifecycle(.done)
    plan.actions = [past, future, doneFuture]

    let remaining = DisruptionService.remainingActions(in: plan, now: now)
    let titles = Set(remaining.map(\.title))
    #expect(titles.contains("Afternoon"))
    #expect(!titles.contains("Morning"), "Past block excluded")
    #expect(!titles.contains("Done already"), "Settled (done) block excluded")
}

// MARK: - REGRESSION: RestBankService can't go negative

@Test func restBankSpendNoOpWhenEmpty() {
    let prefs = UserPreferences()
    prefs.bankedRestDays = 0
    let spent = RestBankService.spend(prefs)
    #expect(spent == false)
    #expect(prefs.bankedRestDays == 0, "Spending an empty bank never goes negative")
}

@Test func restBankSpendIsIdempotentPerDay() {
    let prefs = UserPreferences()
    prefs.bankedRestDays = 2
    #expect(RestBankService.spend(prefs) == true)
    #expect(prefs.bankedRestDays == 1)
    // Second spend the same day is a no-op (can't drain via re-tap).
    #expect(RestBankService.spend(prefs) == false)
    #expect(prefs.bankedRestDays == 1)
    #expect(prefs.restDaysSpentTotal == 1)
}

@Test func restBankRefundReversesSpendWithinSameDay() {
    let prefs = UserPreferences()
    prefs.bankedRestDays = 1
    #expect(RestBankService.spend(prefs) == true)
    #expect(prefs.bankedRestDays == 0)
    #expect(RestBankService.refundToday(prefs) == true)
    #expect(prefs.bankedRestDays == 1)
    #expect(prefs.restDaysSpentTotal == 0)
    #expect(prefs.lastRestDaySpent == nil)
}

@Test func restBankRefundNoOpWhenNothingSpentToday() {
    let prefs = UserPreferences()
    prefs.bankedRestDays = 3
    #expect(RestBankService.refundToday(prefs) == false)
    #expect(prefs.bankedRestDays == 3, "Refund without a same-day spend never inflates the bank")
}

@Test func restBankEarnGrantsAtMostOncePerDayAndNeverFloods() {
    let prefs = UserPreferences()
    // 14-day streak → at most 2 banked days over time.
    let granted = RestBankService.evaluateEarn(prefs, longestLiveStreak: 14)
    #expect(granted == 2)
    #expect(prefs.bankedRestDays == 2)
    // Same day, re-evaluate → no double credit.
    let again = RestBankService.evaluateEarn(prefs, longestLiveStreak: 14)
    #expect(again == 0)
    #expect(prefs.bankedRestDays == 2)
}

@Test func restBankEarnBelowThresholdGrantsNothing() {
    let prefs = UserPreferences()
    let granted = RestBankService.evaluateEarn(prefs, longestLiveStreak: 3)
    #expect(granted == 0)
    #expect(prefs.bankedRestDays == 0)
}
