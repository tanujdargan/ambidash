import Testing
@testable import ambidash

@Test func goalDomainHasExpectedCases() {
    let allCases = GoalDomain.allCases
    #expect(allCases.count == 7)
    #expect(GoalDomain.fitness.displayName == "Fitness & Body")
    #expect(GoalDomain.fitness.dimension == .body)
}

@Test func goalDomainMapsToCorrectDimension() {
    #expect(GoalDomain.fitness.dimension == .body)
    #expect(GoalDomain.cognitive.dimension == .mind)
    #expect(GoalDomain.screenTime.dimension == .focus)
    #expect(GoalDomain.social.dimension == .social)
    #expect(GoalDomain.career.dimension == .growth)
    #expect(GoalDomain.language.dimension == .mind)
    #expect(GoalDomain.financial.dimension == .growth)
}
