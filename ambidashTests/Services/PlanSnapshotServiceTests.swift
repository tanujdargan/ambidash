import Testing
import Foundation
import SwiftData
@testable import ambidash

// Phase 0 — PlanSnapshotService: the persisted "morning plan" that the notification
// "I feel better" action restores. Verifies capture/restore round-trip, don't-clobber,
// and clear, against an isolated UserDefaults suite (hermetic).

private func freshSuite(_ name: String) -> UserDefaults {
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

// Serialized: these mutate PlanSnapshotService's shared static `store`, so they must
// not run concurrently (Swift Testing parallelizes by default).
@Suite(.serialized)
@MainActor
struct PlanSnapshotSuite {

@Test func planSnapshotCapturesAndRestoresOriginal() throws {
    let suite = freshSuite("test.plansnapshot")
    PlanSnapshotService.store = suite
    defer { PlanSnapshotService.store = .standard }

    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext
    let today = Calendar.current.startOfDay(for: .now)
    let plan = DailyPlan(date: today, format: .focusBlocks)
    ctx.insert(plan)
    // A future block so it counts as "remaining" in the snapshot.
    let action = PlannedAction(title: "Deep work", why: "", timeSlot: "23:59", duration: 60)
    ctx.insert(action); action.plan = plan

    // Morning: capture the original.
    PlanSnapshotService.captureOriginal(plan, now: today)
    let saved = PlanSnapshotService.original(for: today)
    #expect(saved?.isEmpty == false)
    #expect(saved?.first?.timeSlot == "23:59")

    // A disruption moves the block; then "I feel better" reverts it.
    action.timeSlot = "08:00"
    if let snap = PlanSnapshotService.original(for: today) {
        DisruptionService.revert(snap, in: plan)
    }
    #expect(action.timeSlot == "23:59")   // restored to the morning original
}

@MainActor
@Test func captureOriginalDoesNotClobberAndClearWorks() throws {
    let suite = freshSuite("test.plansnapshot.clobber")
    PlanSnapshotService.store = suite
    defer { PlanSnapshotService.store = .standard }

    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext
    let today = Calendar.current.startOfDay(for: .now)
    let plan = DailyPlan(date: today, format: .focusBlocks)
    ctx.insert(plan)
    let a = PlannedAction(title: "A", why: "", timeSlot: "23:00", duration: 30)
    ctx.insert(a); a.plan = plan

    PlanSnapshotService.captureOriginal(plan, now: today)
    // A later capture (after the block moved) must NOT overwrite the morning original.
    a.timeSlot = "09:00"
    PlanSnapshotService.captureOriginal(plan, now: today)
    #expect(PlanSnapshotService.original(for: today)?.first?.timeSlot == "23:00")

    PlanSnapshotService.clear(for: today)
    #expect(PlanSnapshotService.original(for: today) == nil)
}
}
