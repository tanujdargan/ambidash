import Testing
import Foundation
import SwiftData
@testable import ambidash

private let cal = Calendar.current
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

// MARK: - Pure window math

@Test func clampKeepsCountInOneToSeven() {
    #expect(MultiDayPlannerService.clampedCount(0) == 1)
    #expect(MultiDayPlannerService.clampedCount(-3) == 1)
    #expect(MultiDayPlannerService.clampedCount(4) == 4)
    #expect(MultiDayPlannerService.clampedCount(9) == 7)
}

@Test func daysReturnsClampedNormalizedWindow() {
    let days = MultiDayPlannerService.days(from: day(2026, 6, 3), count: 3)
    #expect(days.count == 3)
    #expect(cal.isDate(days[0], inSameDayAs: day(2026, 6, 3)))
    #expect(cal.isDate(days[2], inSameDayAs: day(2026, 6, 5)))
    // Over-large count clamps to 7.
    #expect(MultiDayPlannerService.days(from: day(2026, 6, 3), count: 99).count == 7)
}

// MARK: - Big event countdown

@Test func soonestBigEventPicksNearestUpcomingOpenDeadline() {
    let now = day(2026, 6, 3)
    func ms(_ title: String, _ end: Date) -> Milestone {
        Milestone(title: title, period: .week, startDate: now, endDate: end)
    }
    let near = ms("Midterm", day(2026, 6, 5))     // in 2 days
    let far = ms("Final", day(2026, 6, 12))       // in 9 days
    let done = ms("Quiz", day(2026, 6, 4)); done.completedAt = now   // excluded (done)
    let past = ms("Old", day(2026, 6, 1))         // excluded (past)

    let event = MultiDayPlannerService.soonestBigEvent(
        milestones: [far, done, past, near], from: now)
    #expect(event?.title == "Midterm")
    #expect(event?.daysUntil == 2)
    #expect(event?.phrase == "in 2 days")
}

@Test func soonestBigEventNilWhenNothingUpcomingInHorizon() {
    let now = day(2026, 6, 3)
    let m = Milestone(title: "Way off", period: .quarter, startDate: now, endDate: day(2026, 8, 1))
    #expect(MultiDayPlannerService.soonestBigEvent(milestones: [m], from: now) == nil)
}

@Test func bigEventPhraseHandlesTodayAndTomorrow() {
    #expect(BigEventCountdown(title: "x", daysUntil: 0, date: .now).phrase == "today")
    #expect(BigEventCountdown(title: "x", daysUntil: 1, date: .now).phrase == "tomorrow")
}

// MARK: - Move between days (model-level)

@MainActor
@Test func moveReassignsActionToTargetDayPlan() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext

    let today = cal.startOfDay(for: .now)
    let plan = DailyPlan(date: today, format: .focusBlocks)
    ctx.insert(plan)
    let action = PlannedAction(title: "Write essay", why: "", timeSlot: "14:00", duration: 60)
    ctx.insert(action); action.plan = plan
    plan.actionCount = 1

    let target = cal.date(byAdding: .day, value: 2, to: today)!
    let dest = MultiDayPlannerService.move(action, to: target, in: [plan], context: ctx)

    // Action now lives on day +2, not today; single identity (no clone).
    #expect(cal.isDate(dest.date, inSameDayAs: target))
    #expect(action.plan === dest)
    #expect(plan.actions?.isEmpty ?? true)
    #expect(dest.actions?.count == 1)
}

@MainActor
@Test func moveToSameDayIsNoOp() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext
    let today = cal.startOfDay(for: .now)
    let plan = DailyPlan(date: today, format: .focusBlocks)
    ctx.insert(plan)
    let action = PlannedAction(title: "Stay", why: "", timeSlot: "", duration: 30)
    ctx.insert(action); action.plan = plan

    let dest = MultiDayPlannerService.move(action, to: today, in: [plan], context: ctx)
    #expect(dest === plan)
    #expect(action.plan === plan)
}
