import Testing
import Foundation
@testable import ambidash

@Test func goalTracksNeglectDays() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)
    #expect(goal.neglectDays == 0)
    #expect(goal.status == .onTrack)
}

@Test func goalComputesNeglectFromLastProgress() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
    #expect(goal.neglectDays == 5)
}

@Test func goalStatusDegrades() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
    #expect(goal.computedStatus == .onTrack)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
    #expect(goal.computedStatus == .needsAttention)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
    #expect(goal.computedStatus == .slipping)
}
