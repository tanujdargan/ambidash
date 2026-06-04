import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-activity-logging — tests for the PURE pattern-detection + weekly-digest logic. The
// activity itself (ActualEvent/EnergyCheckin/Reflection) is logged elsewhere; here we lock the
// confidence-gated insight detection and the digest aggregation.

private let cal = Calendar(identifier: .gregorian)
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
}

// MARK: - hourLabel

@Test func hourLabelFormats12Hour() {
    #expect(ActivityInsights.hourLabel(9) == "9am")
    #expect(ActivityInsights.hourLabel(13) == "1pm")
    #expect(ActivityInsights.hourLabel(0) == "12am")
    #expect(ActivityInsights.hourLabel(12) == "12pm")
    #expect(ActivityInsights.hourLabel(23) == "11pm")
}

// MARK: - Insight detection

@Test func detectsProductiveWindowWithEnoughSamples() {
    let adherence = [9: (completed: 3, total: 3, ratio: 1.0)]
    let insights = ActivityInsights.detect(
        adherenceByHour: adherence, energyByHour: [:], energySampleCount: 0,
        completedCount: 3, totalLoggedCount: 3, reflectionCount: 0
    )
    let pw = insights.first { $0.id == "productive-window" }
    #expect(pw != nil)
    #expect(pw?.title.contains("9am") == true)
    #expect(pw?.title.contains("11am") == true)
}

@Test func productiveWindowGatedByConfidence() {
    // Only one sample in the hour → below the floor → no insight.
    let adherence = [9: (completed: 1, total: 1, ratio: 1.0)]
    let insights = ActivityInsights.detect(
        adherenceByHour: adherence, energyByHour: [:], energySampleCount: 0,
        completedCount: 1, totalLoggedCount: 1, reflectionCount: 0
    )
    #expect(!insights.contains { $0.id == "productive-window" })
}

@Test func detectsAfternoonSkip() {
    let adherence = [
        8: (completed: 3, total: 3, ratio: 1.0),
        9: (completed: 3, total: 3, ratio: 1.0),
        13: (completed: 0, total: 3, ratio: 0.0),
        14: (completed: 1, total: 3, ratio: 0.33),
    ]
    let insights = ActivityInsights.detect(
        adherenceByHour: adherence, energyByHour: [:], energySampleCount: 0,
        completedCount: 7, totalLoggedCount: 12, reflectionCount: 0
    )
    #expect(insights.contains { $0.id == "afternoon-skip" })
}

@Test func detectsEnergyPeakOnlyWithEnoughCheckins() {
    let energy = [9: 4.6, 18: 2.0]
    let enough = ActivityInsights.detect(
        adherenceByHour: [:], energyByHour: energy, energySampleCount: 6,
        completedCount: 0, totalLoggedCount: 0, reflectionCount: 0
    )
    let peak = enough.first { $0.id == "energy-peak" }
    #expect(peak != nil)
    #expect(peak?.title.contains("morning") == true)

    let tooFew = ActivityInsights.detect(
        adherenceByHour: [:], energyByHour: energy, energySampleCount: 3,
        completedCount: 0, totalLoggedCount: 0, reflectionCount: 0
    )
    #expect(!tooFew.contains { $0.id == "energy-peak" })
}

@Test func detectsCompletionRateAndReflectionHabit() {
    let insights = ActivityInsights.detect(
        adherenceByHour: [:], energyByHour: [:], energySampleCount: 0,
        completedCount: 4, totalLoggedCount: 6, reflectionCount: 3
    )
    let rate = insights.first { $0.id == "completion-rate" }
    #expect(rate?.title.contains("4 of 6") == true)
    #expect(rate?.title.contains("67%") == true)
    let refl = insights.first { $0.id == "reflection-habit" }
    #expect(refl?.title.contains("3 days") == true)
}

@Test func detectsNothingWithNoData() {
    let insights = ActivityInsights.detect(
        adherenceByHour: [:], energyByHour: [:], energySampleCount: 0,
        completedCount: 0, totalLoggedCount: 0, reflectionCount: 0
    )
    #expect(insights.isEmpty)
}

// MARK: - Weekly digest aggregation

@Test func weeklyDigestTalliesOutcomesWithinWindow() {
    let now = at(2024, 5, 10, 12)
    let actuals = [
        ActualEvent(startMinutes: 9 * 60, date: at(2024, 5, 9, 9), completionStatusRaw: "completed"),
        ActualEvent(startMinutes: 10 * 60, date: at(2024, 5, 8, 10), completionStatusRaw: "partial"),
        ActualEvent(startMinutes: 14 * 60, date: at(2024, 5, 7, 14), completionStatusRaw: "abandoned"),
        // Outside the 7-day window → excluded.
        ActualEvent(startMinutes: 9 * 60, date: at(2024, 5, 1, 9), completionStatusRaw: "completed"),
    ]
    let checkins = [
        EnergyCheckin(date: at(2024, 5, 9, 9), level: 4),
        EnergyCheckin(date: at(2024, 5, 8, 9), level: 2),
    ]
    let digest = LearningService.weeklyDigest(actuals: actuals, checkins: checkins, reflectionDayCount: 2, now: now)
    #expect(digest.completedCount == 1)
    #expect(digest.partialCount == 1)
    #expect(digest.abandonedCount == 1)
    #expect(digest.totalLogged == 3)        // the May 1 event is excluded
    #expect(digest.averageEnergy == 3.0)    // (4 + 2) / 2
    #expect(digest.reflectionCount == 2)
    #expect(digest.hasContent)
}

@Test func weeklyDigestIsEmptyWithNoRecentActivity() {
    let now = at(2024, 5, 10, 12)
    let digest = LearningService.weeklyDigest(actuals: [], checkins: [], reflectionDayCount: 0, now: now)
    #expect(digest.totalLogged == 0)
    #expect(digest.averageEnergy == nil)
    #expect(!digest.hasContent)
}
