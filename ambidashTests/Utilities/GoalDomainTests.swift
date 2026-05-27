import Testing
@testable import ambidash

@Test func goalDomainHasExpectedCases() {
    let allCases = GoalDomain.allCases
    #expect(allCases.count == 6)
    #expect(GoalDomain.body.displayName == "Body & Health")
    #expect(GoalDomain.body.dimension == .body)
}

@Test func goalDomainMapsToCorrectDimension() {
    #expect(GoalDomain.body.dimension == .body)
    #expect(GoalDomain.mind.dimension == .mind)
    #expect(GoalDomain.craft.dimension == .craft)
    #expect(GoalDomain.people.dimension == .people)
    #expect(GoalDomain.wealth.dimension == .wealth)
    #expect(GoalDomain.adventure.dimension == .adventure)
}
