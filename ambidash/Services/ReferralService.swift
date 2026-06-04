import Foundation
import SwiftData

/// v4 #11 — referral. Ambidash grows by invite (the CalAI playbook: make sharing
/// frictionless and the reward visible). This service owns the *logic*: stable code
/// generation, redemption validation, and milestone-tier computation — all pure and
/// unit-tested. The view is a thin shell over it. Cross-user attribution (counting
/// who actually joined with your code) needs a backend; `UserProfile.referralCount`
/// is the field that backend would increment, and every other flow works on-device.
enum ReferralService {

    // MARK: - Codes

    /// Trim + uppercase a pasted/typed code so "ambi-1a2b3c " matches "AMBI-1A2B3C".
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// A fresh shareable code: "AMBI-XXXXXX" (6 hex chars off a UUID). Distinct values
    /// per call; stability comes from storing it once on the profile.
    static func generateCode() -> String {
        "AMBI-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).uppercased()
    }

    /// Ensure the profile has a stable referral code, minting one the first time.
    @discardableResult
    static func ensureCode(for profile: UserProfile, context: ModelContext) -> String {
        if profile.referralCode.isEmpty {
            profile.referralCode = generateCode()
            try? context.save()
        }
        return profile.referralCode
    }

    /// The message shared via the system share sheet.
    static func shareText(code: String) -> String {
        "I'm using Ambidash to actually keep up with my goals — it's invite-only. Join with my code \(code): https://ambidash.app/i/\(code)"
    }

    // MARK: - Redemption

    enum RedeemResult: Equatable {
        case ok
        case empty          // nothing entered
        case ownCode        // can't refer yourself
        case alreadyRedeemed // a one-time action; already joined via someone
    }

    /// Pure validation of redeeming an inviter's code. `ownCode` / `existingReferredBy`
    /// are passed in so this can be exercised without a live profile.
    static func validateRedemption(code raw: String, ownCode: String, existingReferredBy: String) -> RedeemResult {
        let code = normalize(raw)
        guard !code.isEmpty else { return .empty }
        guard existingReferredBy.isEmpty else { return .alreadyRedeemed }
        guard code != normalize(ownCode) else { return .ownCode }
        return .ok
    }

    /// Apply a validated redemption: record the inviter's code and grant the one-time
    /// welcome perk. Returns the result so the UI can message failures.
    @discardableResult
    static func redeem(code raw: String, profile: UserProfile, context: ModelContext) -> RedeemResult {
        let result = validateRedemption(code: raw, ownCode: profile.referralCode, existingReferredBy: profile.referredByCode)
        guard result == .ok else { return result }
        profile.referredByCode = normalize(raw)
        profile.referralWelcomeClaimed = true
        try? context.save()
        return .ok
    }

    // MARK: - Milestone tiers

    /// The highest tier earned for a confirmed-referral count.
    static func tier(for count: Int) -> ReferralTier {
        ReferralTier.allCases.last { count >= $0.threshold } ?? .none
    }

    /// The next tier to chase and how many more invites it needs (nil at the top).
    static func nextTier(for count: Int) -> (tier: ReferralTier, remaining: Int)? {
        guard let next = ReferralTier.allCases.first(where: { $0.threshold > count }) else { return nil }
        return (next, next.threshold - count)
    }
}

/// Referral milestones. rawValue == the confirmed-referral threshold, so the enum is
/// both the ladder and its own boundary table; cases stay sorted by threshold.
enum ReferralTier: Int, CaseIterable, Comparable {
    case none = 0
    case connector = 1
    case catalyst = 3
    case amplifier = 5
    case foundingCircle = 10

    var threshold: Int { rawValue }

    static func < (l: ReferralTier, r: ReferralTier) -> Bool { l.rawValue < r.rawValue }

    var title: String {
        switch self {
        case .none: return "Not yet"
        case .connector: return "Connector"
        case .catalyst: return "Catalyst"
        case .amplifier: return "Amplifier"
        case .foundingCircle: return "Founding Circle"
        }
    }

    /// The perk/status earned — cosmetic + standing, since the app itself is unlocked.
    var perk: String {
        switch self {
        case .none: return "Invite a friend to start your circle."
        case .connector: return "Connector badge on your profile."
        case .catalyst: return "Unlock the Founders accent theme."
        case .amplifier: return "Early access to new features."
        case .foundingCircle: return "Founding Circle status — permanent."
        }
    }
}
