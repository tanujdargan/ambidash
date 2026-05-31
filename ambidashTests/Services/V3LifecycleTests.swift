// ambidashTests/Services/V3LifecycleTests.swift
//
// V3 regression + happy-path tests for the ZERO-GUILT lifecycle and its
// interaction with CarryOverService. The headline regression these lock in:
// a carried-over (.deferred) or partly-logged (.partial) action that the user
// then marks done via applyLifecycle(.done) must NOT be re-carried by
// CarryOverService, and must count as a win.
import Testing
import Foundation
import SwiftData
@testable import ambidash

// MARK: - applyLifecycle mirror contract

@Test func applyLifecycleDoneMirrorsStatusAndStampsCompletion() {
    let a = PlannedAction(title: "Read", duration: 30)
    a.applyLifecycle(.done)
    #expect(a.lifecycle == .done)
    #expect(a.statusRaw == "done")
    #expect(a.completedAt != nil)
    #expect(a.partialProgress == 1)
    #expect(a.restMarker == false)
}

@Test func applyLifecycleAbandonedMirrorsToLegacySkipped() {
    let a = PlannedAction(title: "Email", duration: 15)
    a.applyLifecycle(.abandoned)
    #expect(a.lifecycle == .abandoned)
    #expect(a.statusRaw == "skipped")
    #expect(a.restMarker == false)
}

@Test func applyLifecycleRestKeepsStatusPendingAndSetsMarker() {
    let a = PlannedAction(title: "Walk", duration: 20)
    a.applyLifecycle(.rest)
    #expect(a.lifecycle == .rest)
    #expect(a.statusRaw == "pending")   // not a hard skip
    #expect(a.restMarker == true)
}

@Test func applyLifecycleDeferredAndPartialStayPending() {
    let deferred = PlannedAction(title: "A", duration: 10)
    deferred.applyLifecycle(.deferred)
    #expect(deferred.statusRaw == "pending")
    #expect(deferred.restMarker == false)

    let partial = PlannedAction(title: "B", duration: 10)
    partial.applyLifecycle(.partial)
    #expect(partial.statusRaw == "pending")
    #expect(partial.lifecycle == .partial)
}

@Test func lifecycleDerivesFromLegacyStatusWhenRawIsDefault() {
    // A legacy action mutated only via statusRaw (e.g. the Today screen) must
    // still resolve its lifecycle correctly without a migration.
    let done = PlannedAction(title: "Legacy done", duration: 10)
    done.statusRaw = "done"   // lifecycleRaw stays "pending"
    #expect(done.lifecycle == .done)

    let restLegacy = PlannedAction(title: "Legacy rest", duration: 10)
    restLegacy.statusRaw = "skipped"
    restLegacy.restMarker = true
    #expect(restLegacy.lifecycle == .rest)
}

// MARK: - REGRESSION: done-via-applyLifecycle is NOT re-carried

@Test func deferredThenDoneIsNotUnfinished() {
    // A carried-over item resurfaces as .deferred; the user finishes it.
    let a = PlannedAction(title: "Carried task", duration: 30)
    a.applyLifecycle(.deferred)
    #expect(CarryOverService.isUnfinished(a) == true)

    a.applyLifecycle(.done)
    #expect(CarryOverService.isUnfinished(a) == false,
            "A deferred item marked done must not roll forward again")
}

@Test func partialThenDoneIsNotUnfinished() {
    let a = PlannedAction(title: "Half task", duration: 30)
    a.applyLifecycle(.partial)
    a.partialProgress = 0.4
    #expect(CarryOverService.isUnfinished(a) == true)

    a.applyLifecycle(.done)
    #expect(CarryOverService.isUnfinished(a) == false,
            "A partial item marked done must not roll forward again")
}

@Test func restAndAbandonedAreNeverUnfinished() {
    let rest = PlannedAction(title: "Rest", duration: 0)
    rest.applyLifecycle(.rest)
    #expect(CarryOverService.isUnfinished(rest) == false)

    let abandoned = PlannedAction(title: "Let go", duration: 0)
    abandoned.applyLifecycle(.abandoned)
    #expect(CarryOverService.isUnfinished(abandoned) == false)
}

@Test func pendingAndDeferredAndPartialAreUnfinished() {
    let pending = PlannedAction(title: "P", duration: 10)
    #expect(CarryOverService.isUnfinished(pending) == true)

    let deferred = PlannedAction(title: "D", duration: 10)
    deferred.applyLifecycle(.deferred)
    #expect(CarryOverService.isUnfinished(deferred) == true)

    let partial = PlannedAction(title: "Pa", duration: 10)
    partial.applyLifecycle(.partial)
    #expect(CarryOverService.isUnfinished(partial) == true)
}

@Test func legacyBareSkippedStillCarriesButDoneDoesNot() {
    // A bare legacy "skipped" (soft set-aside, lifecycleRaw default) still rolls.
    let softSkip = PlannedAction(title: "Soft", duration: 10)
    softSkip.statusRaw = "skipped"   // not via applyLifecycle → no rest/abandon
    #expect(CarryOverService.isUnfinished(softSkip) == true)

    let legacyDone = PlannedAction(title: "Done", duration: 10)
    legacyDone.statusRaw = "done"
    #expect(CarryOverService.isUnfinished(legacyDone) == false)
}

// MARK: - REGRESSION: carryForward excludes the just-done item (integration)

@MainActor
@Test func carryForwardSkipsDoneAndDeferredButCarriesUnfinished() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now))!
    let prior = DailyPlan(date: yesterday)
    ctx.insert(prior)

    let finished = PlannedAction(title: "Finished work", duration: 30)
    finished.applyLifecycle(.deferred)   // was carried...
    finished.applyLifecycle(.done)       // ...then completed → must NOT re-carry
    finished.plan = prior
    ctx.insert(finished)

    let stillOpen = PlannedAction(title: "Open work", duration: 30)
    stillOpen.applyLifecycle(.partial)
    stillOpen.partialProgress = 0.5
    stillOpen.plan = prior
    ctx.insert(stillOpen)

    let rested = PlannedAction(title: "Rested", duration: 0)
    rested.applyLifecycle(.rest)
    rested.plan = prior
    ctx.insert(rested)

    let today = DailyPlan(date: cal.startOfDay(for: .now))
    ctx.insert(today)

    CarryOverService.carryForward(into: today, from: prior, context: ctx)

    let carried = (today.actions ?? [])
    #expect(carried.count == 1, "Only the still-open partial should carry")
    #expect(carried.first?.title == "Open work")
    #expect(carried.first?.lifecycle == .deferred)
    #expect(carried.first?.partialProgress == 0.5, "Partial progress is preserved")
    #expect(carried.first?.carriedOverFrom == yesterday)
}

@MainActor
@Test func carryForwardIsIdempotent() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)
    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now))!

    let prior = DailyPlan(date: yesterday)
    ctx.insert(prior)
    let open = PlannedAction(title: "Open", duration: 30)
    open.plan = prior
    ctx.insert(open)

    let today = DailyPlan(date: cal.startOfDay(for: .now))
    ctx.insert(today)

    CarryOverService.carryForward(into: today, from: prior, context: ctx)
    CarryOverService.carryForward(into: today, from: prior, context: ctx)

    #expect((today.actions ?? []).count == 1, "Re-running carry must not double-clone")
}
