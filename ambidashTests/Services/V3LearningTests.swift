// ambidashTests/Services/V3LearningTests.swift
//
// V3 tests for the on-device LearningService pure helpers: the median (used for
// per-goal typical durations) and inferWakeSleep, including the overnight
// (end < start) health-sample path that mirrors the ActualEvent duration fix.
import Testing
import Foundation
@testable import ambidash

// MARK: - median

@Test func medianOfEmptyIsZero() {
    #expect(LearningService.median([]) == 0)
}

@Test func medianOfSingleValue() {
    #expect(LearningService.median([42]) == 42)
}

@Test func medianOddCountIsMiddle() {
    #expect(LearningService.median([30, 10, 20]) == 20) // sorted: 10,20,30
}

@Test func medianEvenCountIsAverageOfMiddlePair() {
    #expect(LearningService.median([10, 20, 30, 40]) == 25)
}

@Test func medianResistsOutliers() {
    // A single very-long block shouldn't drag the estimate the way a mean would.
    let values = [20, 22, 25, 24, 600]
    #expect(LearningService.median(values) == 24)
}

// MARK: - inferWakeSleep

@Test func inferWakeSleepReturnsNilWithoutHealthSamples() {
    // Manual logs say nothing about real wake/sleep → graceful no-op.
    let manual = [
        ActualEvent(startMinutes: 9 * 60, endMinutes: 10 * 60, date: .now, sourceRaw: "manual"),
        ActualEvent(startMinutes: 14 * 60, endMinutes: 15 * 60, date: .now, sourceRaw: "manual"),
    ]
    let result = LearningService.inferWakeSleep(actuals: manual)
    #expect(result.wakeMinutes == nil)
    #expect(result.sleepMinutes == nil)
}

@Test func inferWakeSleepOvernightSampleReadsWakeAndBedtimeCorrectly() {
    // Overnight sleep sample: bed 23:00 (start), wake 07:00 (end), end < start.
    // Wake must be the END (420), bedtime the START (1380) — NOT swapped.
    let overnight = ActualEvent(
        startMinutes: 23 * 60,
        endMinutes: 7 * 60,
        date: .now,
        sourceRaw: "health"
    )
    let result = LearningService.inferWakeSleep(actuals: [overnight])
    #expect(result.wakeMinutes == 7 * 60)
    #expect(result.sleepMinutes == 23 * 60)
}

@Test func inferWakeSleepSameDayHealthUsesStartAndEnd() {
    // A same-day health workout 06:30 → 19:00 → wake floor 06:30, sleep ceil 19:00.
    let workout = ActualEvent(
        startMinutes: 6 * 60 + 30,
        endMinutes: 19 * 60,
        date: .now,
        sourceRaw: "health"
    )
    let result = LearningService.inferWakeSleep(actuals: [workout])
    #expect(result.wakeMinutes == 6 * 60 + 30)
    #expect(result.sleepMinutes == 19 * 60)
}
