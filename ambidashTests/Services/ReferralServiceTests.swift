import Testing
import Foundation
import SwiftData
@testable import ambidash

// MARK: - Codes

@Test func normalizeTrimsAndUppercases() {
    #expect(ReferralService.normalize("  ambi-1a2b3c ") == "AMBI-1A2B3C")
    #expect(ReferralService.normalize("Join123") == "JOIN123")
}

@Test func generateCodeHasExpectedShape() {
    let code = ReferralService.generateCode()
    #expect(code.hasPrefix("AMBI-"))
    #expect(code.count == 11)                    // "AMBI-" + 6
    #expect(code == code.uppercased())
    // No stray hyphen carried in from the UUID's grouping.
    #expect(code.dropFirst(5).contains("-") == false)
}

@Test func shareTextContainsCodeAndLink() {
    let text = ReferralService.shareText(code: "AMBI-ABC123")
    #expect(text.contains("AMBI-ABC123"))
    #expect(text.contains("ambidash.app/i/AMBI-ABC123"))
}

// MARK: - Redemption validation (pure)

@Test func validateRedemptionAcceptsAFreshOthersCode() {
    #expect(ReferralService.validateRedemption(code: "ambi-xyz999", ownCode: "AMBI-MINE01", existingReferredBy: "") == .ok)
}

@Test func validateRedemptionRejectsEmptyOwnAndRepeat() {
    #expect(ReferralService.validateRedemption(code: "   ", ownCode: "AMBI-MINE01", existingReferredBy: "") == .empty)
    // Own code, even with different casing/whitespace, is rejected.
    #expect(ReferralService.validateRedemption(code: " ambi-mine01 ", ownCode: "AMBI-MINE01", existingReferredBy: "") == .ownCode)
    // Already redeemed once.
    #expect(ReferralService.validateRedemption(code: "AMBI-OTHER0", ownCode: "AMBI-MINE01", existingReferredBy: "AMBI-FIRST0") == .alreadyRedeemed)
}

// MARK: - Milestone tiers

@Test func tierLadderMapsCountsToTiers() {
    #expect(ReferralService.tier(for: 0) == .none)
    #expect(ReferralService.tier(for: 1) == .connector)
    #expect(ReferralService.tier(for: 2) == .connector)
    #expect(ReferralService.tier(for: 3) == .catalyst)
    #expect(ReferralService.tier(for: 7) == .amplifier)
    #expect(ReferralService.tier(for: 25) == .foundingCircle)
}

@Test func nextTierReportsRemainingAndCapsAtTop() {
    let n0 = ReferralService.nextTier(for: 0)
    #expect(n0?.tier == .connector)
    #expect(n0?.remaining == 1)

    let n1 = ReferralService.nextTier(for: 1)
    #expect(n1?.tier == .catalyst)
    #expect(n1?.remaining == 2)

    #expect(ReferralService.nextTier(for: 10) == nil)   // at the top
}

// MARK: - Redeem (model-level)

@MainActor
@Test func redeemRecordsInviterAndClaimsWelcomeOnce() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext
    let profile = UserProfile(name: "Test")
    ctx.insert(profile)
    profile.referralCode = "AMBI-MINE01"

    let first = ReferralService.redeem(code: "ambi-friend", profile: profile, context: ctx)
    #expect(first == .ok)
    #expect(profile.referredByCode == "AMBI-FRIEND")
    #expect(profile.referralWelcomeClaimed == true)

    // A second redemption is refused — welcome perk is one-time.
    let second = ReferralService.redeem(code: "AMBI-OTHER0", profile: profile, context: ctx)
    #expect(second == .alreadyRedeemed)
    #expect(profile.referredByCode == "AMBI-FRIEND")   // unchanged
}

@MainActor
@Test func ensureCodeIsStableAcrossCalls() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = container.mainContext
    let profile = UserProfile(name: "Test")
    ctx.insert(profile)

    let a = ReferralService.ensureCode(for: profile, context: ctx)
    let b = ReferralService.ensureCode(for: profile, context: ctx)
    #expect(a == b)
    #expect(a.hasPrefix("AMBI-"))
}
