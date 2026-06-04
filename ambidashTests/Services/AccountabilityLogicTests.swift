import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-social-accountability — tests for the PURE accountability logic: invite validation,
// daily check-in status, the accountability score, and celebration messages. Supabase sync and
// SwiftData persistence are exercised elsewhere; all branching lives here.

private typealias A = AccountabilityLogic
private let cal = Calendar(identifier: .gregorian)
private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

// MARK: - Invite validation

@Test func validateInviteAcceptsAndNormalizes() {
    let result = A.validateInvite(code: " ambi-1a2b3c ", ownCode: "AMBI-ZZZZZZ", existingPartnerCodes: [])
    #expect(result == .valid("AMBI-1A2B3C"))
}

@Test func validateInviteRejectsEmptyOwnAndDuplicate() {
    #expect(A.validateInvite(code: "   ", ownCode: "AMBI-AAA111", existingPartnerCodes: []) == .empty)
    #expect(A.validateInvite(code: "ambi-aaa111", ownCode: "AMBI-AAA111", existingPartnerCodes: []) == .ownCode)
    #expect(A.validateInvite(code: "AMBI-BBB222", ownCode: "AMBI-AAA111", existingPartnerCodes: ["ambi-bbb222"]) == .alreadyPartner)
}

// MARK: - Check-in status

@Test func hasCheckedInTodayReflectsDate() {
    let now = day(2024, 6, 1, 15)
    #expect(A.hasCheckedInToday(nil, now: now, calendar: cal) == false)
    #expect(A.hasCheckedInToday(day(2024, 6, 1, 8), now: now, calendar: cal) == true)
    #expect(A.hasCheckedInToday(day(2024, 5, 31, 23), now: now, calendar: cal) == false)
}

@Test func partnerStatusLabelReadsWarmly() {
    let now = day(2024, 6, 10, 12)
    #expect(A.partnerStatusLabel(lastCheckIn: nil, now: now, calendar: cal) == "No check-in yet")
    #expect(A.partnerStatusLabel(lastCheckIn: day(2024, 6, 10, 8), now: now, calendar: cal) == "Checked in today")
    #expect(A.partnerStatusLabel(lastCheckIn: day(2024, 6, 9, 20), now: now, calendar: cal) == "Checked in yesterday")
    #expect(A.partnerStatusLabel(lastCheckIn: day(2024, 6, 7, 9), now: now, calendar: cal) == "Last checked in 3d ago")
}

// MARK: - Score

@Test func scoreIsFullWithPerfectInputs() {
    #expect(A.score(checkInDays: 7, windowDays: 7, currentStreak: 30, messagesSent: 10) == 100)
}

@Test func scoreIsZeroWithNothing() {
    #expect(A.score(checkInDays: 0, windowDays: 7, currentStreak: 0, messagesSent: 0) == 0)
}

@Test func scoreWeightsConsistencyMost() {
    // Perfect consistency alone = 60 of 100.
    #expect(A.score(checkInDays: 7, windowDays: 7, currentStreak: 0, messagesSent: 0) == 60)
}

@Test func scoreClampsStreakAndSupport() {
    // Streak/support beyond their caps don't push past their weights.
    let capped = A.score(checkInDays: 0, windowDays: 7, currentStreak: 100, messagesSent: 50)
    #expect(capped == 25 + 15) // streak 25 + support 15
}

@Test func scoreHandlesZeroWindow() {
    #expect(A.score(checkInDays: 0, windowDays: 0, currentStreak: 0, messagesSent: 0) == 0)
}

@Test func scoreBandsAreLabeled() {
    #expect(A.scoreBand(90) == "Rock solid")
    #expect(A.scoreBand(60) == "Going strong")
    #expect(A.scoreBand(40) == "Finding your rhythm")
    #expect(A.scoreBand(10) == "Just getting started")
}

// MARK: - Messages

@Test func celebrationFiresOnlyOnMilestones() {
    #expect(A.celebrationMessage(forStreak: 7) != nil)
    #expect(A.celebrationMessage(forStreak: 30) != nil)
    #expect(A.celebrationMessage(forStreak: 200) != nil) // every 100 past 100
    #expect(A.celebrationMessage(forStreak: 8) == nil)
    #expect(A.celebrationMessage(forStreak: 0) == nil)
}

@Test func suggestedEncouragementsAreNonEmpty() {
    #expect(!A.suggestedEncouragements().isEmpty)
    #expect(A.suggestedEncouragements().allSatisfy { !$0.isEmpty })
}
