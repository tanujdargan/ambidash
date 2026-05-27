import Testing
import Foundation
@testable import ambidash

@Test func goalHealthReturnsOnTrackForRecentProgress() {
    let goal = Goal(title: "Test", domain: .body, priority: 1)
    goal.lastProgressDate = .now
    let status = GoalHealthService.status(for: goal)
    #expect(status == .onTrack)
}

@Test func goalHealthReturnsSlippingForNeglectedGoal() {
    let goal = Goal(title: "Test", domain: .body, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
    let status = GoalHealthService.status(for: goal)
    #expect(status == .slipping)
}

@Test func goalHealthReturnsPausedForInactiveGoal() {
    let goal = Goal(title: "Test", domain: .body, priority: 1)
    goal.isActive = false
    let status = GoalHealthService.status(for: goal)
    #expect(status == .paused)
}

@Test func goalHealthSummaryTextForSlipping() {
    let goal = Goal(title: "Lean Body", domain: .body, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
    let summary = GoalHealthService.summaryText(for: goal)
    #expect(summary.contains("8 days"))
}
