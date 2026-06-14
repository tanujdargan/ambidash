import Foundation

// Phase 1 (money rails) — the pricing model + entitlement resolver, as code.
//
// IMPORTANT: the app currently ships everything-unlocked (PremiumGateService.isPremium ==
// true; AI features just need a bring-your-own Anthropic key). This file DEFINES the plan's
// monetization (annual $39.99 lead / 14-day trial / free BYOK funnel / $79 lifetime founder
// capped at 500 / 40% student) and a pure tier resolver, WITHOUT flipping live gating.
// Turning the paywall on (have PremiumGateService honor `unlocksAI`) + adopting RevenueCat
// + the 3-arm trial A/B on realized revenue are the founder's go-live decisions — see the
// PR notes. Keeping it as config + a tested resolver means the rails are ready without
// changing today's UX.
enum MonetizationTier: String, CaseIterable, Equatable {
    case free       // no subscription, no key — productivity core only
    case byok       // brought their own Anthropic key — the free funnel; AI unlocked
    case trial      // inside the 14-day trial
    case premium    // active paid subscription
    case founder    // $79 lifetime founder seat
}

enum MonetizationConfig {
    // Pricing (from the market research).
    static let annualPriceUSD = 39.99
    static let trialDays = 14
    static let lifetimeFounderPriceUSD = 79.0
    static let founderSeatCap = 500
    static let studentDiscount = 0.40   // 40% off

    // Product identifiers (the annual one mirrors SubscriptionService.premiumYearlyID).
    static let annualProductID = "com.ambidash.premium.yearly"
    static let lifetimeFounderProductID = "com.ambidash.founder.lifetime"

    /// The user's effective tier, by precedence. BYOK is a real, permanent free tier (the
    /// acquisition funnel) — owning an Anthropic key unlocks AI without paying.
    static func tier(hasActiveSubscription: Bool, isLifetimeFounder: Bool,
                     hasBYOKKey: Bool, trialActive: Bool) -> MonetizationTier {
        if isLifetimeFounder { return .founder }
        if hasActiveSubscription { return .premium }
        if trialActive { return .trial }
        if hasBYOKKey { return .byok }
        return .free
    }

    /// Whether a tier unlocks the AI / premium surfaces. Only the bare `.free` tier is gated.
    static func unlocksAI(_ tier: MonetizationTier) -> Bool {
        tier != .free
    }

    /// The student-discounted price for a base price, rounded to cents.
    static func studentPrice(_ base: Double) -> Double {
        ((base * (1 - studentDiscount)) * 100).rounded() / 100
    }

    /// Whether founder seats remain (capped acquisition lever).
    static func founderSeatsAvailable(claimed: Int) -> Bool { claimed < founderSeatCap }
}
