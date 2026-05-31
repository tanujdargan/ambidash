// ambidashTests/Services/V3CaptureWinsTests.swift
//
// V3 happy-path tests for WinsService — the non-punitive wins roll-up. Key
// invariants: PARTIALS COUNT as wins, abandoned items never count, and an
// actual linked to a planned action supersedes that action (no double-count).
import Testing
import Foundation
import SwiftData
@testable import ambidash

private func todayInterval() -> DateInterval {
    WinsService.recentInterval(days: 1)
}

@Test func winsCountsCompletedAndPartialPlannedActions() {
    let cal = Calendar.current
    let plan = DailyPlan(date: cal.startOfDay(for: .now))
    let done = PlannedAction(title: "Done thing", timeSlot: "09:00", duration: 30)
    done.applyLifecycle(.done)
    let partial = PlannedAction(title: "Partial thing", timeSlot: "11:00", duration: 30)
    partial.applyLifecycle(.partial)
    let pending = PlannedAction(title: "Pending thing", timeSlot: "13:00", duration: 30)
    plan.actions = [done, partial, pending]

    let wins = WinsService.wins(in: todayInterval(), actuals: [], plans: [plan])
    let titles = Set(wins.map(\.title))
    #expect(titles.contains("Done thing"))
    #expect(titles.contains("Partial thing"), "Partials must count as wins")
    #expect(!titles.contains("Pending thing"), "Pending work is not a win")

    let partialWin = wins.first { $0.title == "Partial thing" }
    #expect(partialWin?.isPartial == true)
}

@Test func winsCountsPartialActualEventsAndExcludesAbandoned() {
    let interval = todayInterval()
    let day = Calendar.current.startOfDay(for: .now)
    let partialActual = ActualEvent(title: "Half a run", startMinutes: 7 * 60, endMinutes: 7 * 60 + 15, date: day, completionStatusRaw: "partial")
    let abandoned = ActualEvent(title: "Skipped", startMinutes: 8 * 60, endMinutes: 8 * 60, date: day, completionStatusRaw: "abandoned")
    let completed = ActualEvent(title: "Wrote", startMinutes: 9 * 60, endMinutes: 10 * 60, date: day, completionStatusRaw: "completed")

    let wins = WinsService.wins(in: interval, actuals: [partialActual, abandoned, completed], plans: [])
    let titles = Set(wins.map(\.title))
    #expect(titles.contains("Half a run"))
    #expect(titles.contains("Wrote"))
    #expect(!titles.contains("Skipped"), "Abandoned actuals are never wins")
    #expect(wins.first { $0.title == "Half a run" }?.isPartial == true)
}

@Test func winsDedupActualSupersedesLinkedPlannedAction() {
    let cal = Calendar.current
    let day = cal.startOfDay(for: .now)
    let plan = DailyPlan(date: day)
    let action = PlannedAction(title: "Gym", timeSlot: "06:00", duration: 45)
    action.applyLifecycle(.done)
    plan.actions = [action]

    // An actual logged against the SAME action — must not double-count.
    let actual = ActualEvent(title: "Gym (logged)", startMinutes: 6 * 60, endMinutes: 7 * 60, date: day, linkedActionID: action.id)

    let wins = WinsService.wins(in: todayInterval(), actuals: [actual], plans: [plan])
    #expect(wins.count == 1, "The actual supersedes the planned action — counted once")
    #expect(wins.first?.title == "Gym (logged)")
}

@Test func winsHeadlineHonorsPartialsAndEmptyGently() {
    #expect(WinsService.headline(count: 0, days: 7).contains("show up here"))
    #expect(WinsService.headline(count: 1, days: 1).contains("counts"))
    let many = WinsService.headline(count: 3, days: 7)
    #expect(many.contains("3 wins"))
    #expect(many.contains("partials"))
}

@Test func winsGroupedBucketsByDayNewestFirst() {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    let interval = WinsService.recentInterval(days: 2)

    let a = ActualEvent(title: "Today win", startMinutes: 9 * 60, endMinutes: 10 * 60, date: today)
    let b = ActualEvent(title: "Yesterday win", startMinutes: 9 * 60, endMinutes: 10 * 60, date: yesterday)

    let flat = WinsService.wins(in: interval, actuals: [a, b], plans: [])
    let grouped = WinsService.grouped(flat)
    #expect(grouped.count == 2)
    #expect(grouped.first?.day == today, "Newest day first")
}

@Test func winsEmptyWindowProducesNoItems() {
    let wins = WinsService.wins(in: todayInterval(), actuals: [], plans: [])
    #expect(wins.isEmpty)
}
