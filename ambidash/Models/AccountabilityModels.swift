// ambidash/Models/AccountabilityModels.swift
//
// v5 feat/v5-social-accountability — local persistence for accountability partners and the
// encouragement messages between them. Partners are linked by an invite code (reusing the
// ReferralService code format); real-time fan-out is handled by SupabaseService when configured,
// but the local SwiftData copy is the source of truth the UI renders so everything works offline.
//
// CloudKit-safe: all scalars defaulted, no required relationships.
import Foundation
import SwiftData

/// An accountability partner — someone the user pairs with by exchanging invite codes. Holds the
/// partner's display info plus the locally-known status of their daily check-in and streak (kept
/// in sync from Supabase when online).
@Model
final class AccountabilityPartner {
    var id: UUID = UUID()
    /// The partner's invite code (links the two accounts; AMBI-XXXXXX format).
    var code: String = ""
    var displayName: String = ""
    /// `pending` (invite sent, not yet accepted) | `active`.
    var statusRaw: String = "pending"
    var createdAt: Date = Date.now
    /// When the partner last checked in (nil = not yet today / unknown).
    var lastCheckInDate: Date? = nil
    /// The partner's current self-reported streak.
    var partnerStreak: Int = 0
    /// How many encouragement messages the user has sent this partner (feeds the
    /// user's own accountability score — being a good partner counts).
    var messagesSent: Int = 0

    init(code: String = "", displayName: String = "", statusRaw: String = "pending") {
        self.id = UUID()
        self.code = code
        self.displayName = displayName
        self.statusRaw = statusRaw
        self.createdAt = .now
    }

    var status: AccountabilityStatus {
        get { AccountabilityStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

enum AccountabilityStatus: String, CaseIterable, Codable, Hashable {
    case pending
    case active

    var label: String {
        switch self {
        case .pending: return "Invite sent"
        case .active: return "Active"
        }
    }
}

/// A short encouragement or celebration note between partners. Stored locally and (when online)
/// fanned out via Supabase. `fromMe` distinguishes sent vs received in the thread.
@Model
final class EncouragementMessage {
    var id: UUID = UUID()
    /// The partner code this message is with.
    var partnerCode: String = ""
    var text: String = ""
    var sentAt: Date = Date.now
    var fromMe: Bool = true
    /// `encouragement` (a nudge of support) | `celebration` (a milestone/streak high-five).
    var kindRaw: String = "encouragement"

    init(partnerCode: String = "", text: String = "", fromMe: Bool = true, kindRaw: String = "encouragement") {
        self.id = UUID()
        self.partnerCode = partnerCode
        self.text = text
        self.fromMe = fromMe
        self.kindRaw = kindRaw
        self.sentAt = .now
    }

    var kind: EncouragementKind {
        get { EncouragementKind(rawValue: kindRaw) ?? .encouragement }
        set { kindRaw = newValue.rawValue }
    }
}

enum EncouragementKind: String, CaseIterable, Codable, Hashable {
    case encouragement
    case celebration
}
