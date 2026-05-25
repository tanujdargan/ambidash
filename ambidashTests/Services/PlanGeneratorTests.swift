// ambidashTests/Services/PlanGeneratorTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func planGeneratorCreatesActionsForActiveGoals() {
    let goals = [
        Goal(title: "Lean Body", domain: .fitness, priority: 1),
        Goal(title: "SWE Skills", domain: .career, priority: 2),
        Goal(title: "Language", domain: .language, priority: 3),
    ]
    let actions = PlanGenerator.generateActions(for: goals, freeMinutes: 480, maxActions: 6)
    #expect(!actions.isEmpty)
    #expect(actions.count <= 6)
    #expect(actions.allSatisfy { !$0.title.isEmpty })
}

@Test func planGeneratorRespectsMaxActions() {
    let goals = (1...10).map { Goal(title: "Goal \($0)", domain: .fitness, priority: $0) }
    let actions = PlanGenerator.generateActions(for: goals, freeMinutes: 480, maxActions: 4)
    #expect(actions.count <= 4)
}

@Test func planGeneratorPrioritizesNeglectedGoals() {
    let fresh = Goal(title: "Fresh", domain: .fitness, priority: 1)
    fresh.lastProgressDate = .now

    let neglected = Goal(title: "Neglected", domain: .career, priority: 2)
    neglected.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!

    let actions = PlanGenerator.generateActions(for: [fresh, neglected], freeMinutes: 480, maxActions: 6)
    let neglectedActions = actions.filter { $0.goalTitle == "Neglected" }
    let freshActions = actions.filter { $0.goalTitle == "Fresh" }
    #expect(neglectedActions.count >= freshActions.count)
}

@Test func planGeneratorHandlesNoGoals() {
    let actions = PlanGenerator.generateActions(for: [], freeMinutes: 480, maxActions: 6)
    #expect(actions.isEmpty)
}
