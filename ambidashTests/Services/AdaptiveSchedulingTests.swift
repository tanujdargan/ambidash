import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-adaptive-scheduling — tests for the empathetic adaptive suggestions: health-aware
// lightening, no-guilt missed-block rescheduling, carry-forward-with-context, and recurring-issue
// detection. All pure; they produce in-memory AdaptiveSuggestions and mutate nothing.

// MARK: - Clock helper

@Test func clockByAddingShiftsAndWraps() {
    #expect(AdaptiveScheduling.clockByAdding(minutes: 90, to: "07:00") == "08:30")
    #expect(AdaptiveScheduling.clockByAdding(minutes: -30, to: "23:30") == "23:00")
    #expect(AdaptiveScheduling.clockByAdding(minutes: 60, to: "23:30") == "00:30") // wraps midnight
    #expect(AdaptiveScheduling.clockByAdding(minutes: 30, to: "not a time") == "not a time")
}

// MARK: - Health-aware lighten

@Test func healthLightenOffersOnRoughSleep() {
    let s = DisruptionService.healthLightenSuggestion(sleepHours: 4.5, plannedGoalBlocks: 5)
    #expect(s != nil)
    #expect(s?.kind == .healthLighten)
    #expect(s?.body.contains("4.5h") == true)
    #expect(s?.options.first?.isPrimary == true)
    #expect(s?.options.count == 2)
}

@Test func healthLightenQuietOnGoodOrUnknownSleep() {
    #expect(DisruptionService.healthLightenSuggestion(sleepHours: 8, plannedGoalBlocks: 5) == nil)
    #expect(DisruptionService.healthLightenSuggestion(sleepHours: 0, plannedGoalBlocks: 5) == nil)
    // Exactly at the threshold is "okay rest" → no nag.
    #expect(DisruptionService.healthLightenSuggestion(sleepHours: 6, plannedGoalBlocks: 5) == nil)
    #expect(DisruptionService.healthLightenSuggestion(sleepHours: 5.9, plannedGoalBlocks: 1) != nil)
}

// MARK: - Missed reschedule

@Test func rescheduleProposesFreeSlotForSingleMiss() {
    let s = DisruptionService.rescheduleMissedSuggestion(
        missed: [.init(title: "Deep work", originalSlot: "09:00")],
        freeSlots: ["14:00", "16:00"]
    )
    #expect(s?.kind == .missedReschedule)
    #expect(s?.options.first?.label == "Move \"Deep work\" to 14:00")
}

@Test func rescheduleCarriesToTomorrowWhenDayIsFull() {
    let s = DisruptionService.rescheduleMissedSuggestion(
        missed: [.init(title: "Deep work", originalSlot: "09:00")],
        freeSlots: []
    )
    #expect(s?.options.first?.label == "Carry \"Deep work\" to tomorrow")
}

@Test func rescheduleNilWhenNothingMissed() {
    #expect(DisruptionService.rescheduleMissedSuggestion(missed: [], freeSlots: ["14:00"]) == nil)
}

@Test func rescheduleSummarizesMultipleMisses() {
    let s = DisruptionService.rescheduleMissedSuggestion(
        missed: [.init(title: "A", originalSlot: "09:00"), .init(title: "B", originalSlot: "10:00")],
        freeSlots: ["14:00"]
    )
    #expect(s?.title.contains("2 blocks slipped") == true)
    #expect(s?.options.first?.label == "Fit them back in later today")
}

// MARK: - Carry forward

@Test func carryForwardAsksWithContext() {
    let s = DisruptionService.carryForwardSuggestion(unfinished: [.init(title: "Gym", goalTitle: "Fitness")])
    #expect(s?.kind == .carryForward)
    #expect(s?.title.contains("Gym") == true)
    #expect(s?.body.contains("for Fitness") == true)
    #expect(s?.options.map(\.id) == ["reschedule", "letgo"])
}

@Test func carryForwardSummarizesMultiple() {
    let s = DisruptionService.carryForwardSuggestion(unfinished: [
        .init(title: "A", goalTitle: nil), .init(title: "B", goalTitle: nil),
    ])
    #expect(s?.title == "2 things rolled over from yesterday")
}

@Test func carryForwardNilWhenEmpty() {
    #expect(DisruptionService.carryForwardSuggestion(unfinished: []) == nil)
}

// MARK: - Recurring issue

@Test func recurringWakeIssueOffersTwoLevers() {
    let s = PatternCheckInService.recurringWakeIssue(
        lateWakeDays: 5, avgDriftMinutes: 45, currentWake: "07:00", currentSleep: "23:30"
    )
    #expect(s?.kind == .recurringIssue)
    #expect(s?.options.count == 2)
    #expect(s?.options.first?.label == "Move wake to 07:45")     // 07:00 + 45m
    #expect(s?.options.last?.label == "Wind down by 23:00 instead") // 23:30 - 30m
}

@Test func recurringWakeIssueQuietBelowThresholds() {
    // Too few days.
    #expect(PatternCheckInService.recurringWakeIssue(lateWakeDays: 3, avgDriftMinutes: 60, currentWake: "07:00", currentSleep: "23:30") == nil)
    // Drift too small.
    #expect(PatternCheckInService.recurringWakeIssue(lateWakeDays: 6, avgDriftMinutes: 20, currentWake: "07:00", currentSleep: "23:30") == nil)
}
