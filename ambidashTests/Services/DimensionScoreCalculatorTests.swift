import Testing
import Foundation
@testable import ambidash

@Test func dimensionScoreFromGoals() {
    let goals = [
        makeGoal(domain: .fitness, neglectDays: 0),
        makeGoal(domain: .cognitive, neglectDays: 5),
        makeGoal(domain: .social, neglectDays: 12),
    ]
    let scores = DimensionScoreCalculator.scores(from: goals, snapshot: nil)

    #expect(scores[.body]! > scores[.social]!)
    #expect(scores[.body]! >= 70)
    #expect(scores[.social]! <= 40)
}

@Test func dimensionScoreDefaults50WhenNoDimGoals() {
    let goals: [Goal] = []
    let scores = DimensionScoreCalculator.scores(from: goals, snapshot: nil)
    for dim in LifeDimension.allCases {
        #expect(scores[dim] == 50)
    }
}

private func makeGoal(domain: GoalDomain, neglectDays: Int) -> Goal {
    let goal = Goal(title: domain.displayName, domain: domain, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -neglectDays, to: .now)!
    return goal
}
