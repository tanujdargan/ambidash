// ambidash/Services/AccountabilityLogic.swift
//
// v5 feat/v5-social-accountability — the PURE logic behind accountability partners: validating an
// invite code (reusing ReferralService's code format), reading a partner's daily check-in status,
// computing an accountability score, and suggesting encouragement/celebration messages. No
// SwiftData/Supabase dependency, so it's fully unit-testable; the views + sync layer feed it data.
import Foundation

enum AccountabilityLogic {

    // MARK: - Invite validation

    enum InviteResult: Equatable {
        case valid(String)      // normalized code, ready to add
        case empty
        case ownCode            // can't partner with yourself
        case alreadyPartner     // already paired with this code
    }

    /// Validate a pasted partner invite code against the user's own code + existing partners.
    /// Reuses ReferralService.normalize so "ambi-1a2b3c " matches "AMBI-1A2B3C".
    static func validateInvite(code raw: String, ownCode: String, existingPartnerCodes: [String]) -> InviteResult {
        let code = ReferralService.normalize(raw)
        guard !code.isEmpty else { return .empty }
        guard code != ReferralService.normalize(ownCode) else { return .ownCode }
        let existing = Set(existingPartnerCodes.map(ReferralService.normalize))
        guard !existing.contains(code) else { return .alreadyPartner }
        return .valid(code)
    }

    // MARK: - Daily check-in status

    /// Whether a partner has checked in today (a logged check-in dated today).
    static func hasCheckedInToday(_ lastCheckIn: Date?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let last = lastCheckIn else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }

    /// A short, warm status label for a partner's check-in state.
    static func partnerStatusLabel(lastCheckIn: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let last = lastCheckIn else { return "No check-in yet" }
        if calendar.isDate(last, inSameDayAs: now) { return "Checked in today" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 1 { return "Checked in yesterday" }
        return "Last checked in \(days)d ago"
    }

    // MARK: - Accountability score

    /// A 0–100 accountability score combining check-in consistency, current streak, and being a
    /// supportive partner. Non-punitive: it rewards showing up and supporting others, never
    /// penalizes — an empty week is simply a low-but-recoverable number.
    ///
    /// Weighting: consistency 60, streak 25, support 15.
    static func score(checkInDays: Int, windowDays: Int, currentStreak: Int, messagesSent: Int) -> Int {
        let consistency = windowDays > 0 ? Double(min(checkInDays, windowDays)) / Double(windowDays) : 0
        let streakBonus = Double(min(max(currentStreak, 0), 30)) / 30.0
        let support = Double(min(max(messagesSent, 0), 10)) / 10.0
        let raw = consistency * 60 + streakBonus * 25 + support * 15
        return max(0, min(100, Int(raw.rounded())))
    }

    /// A warm one-line summary of a score band.
    static func scoreBand(_ score: Int) -> String {
        switch score {
        case 80...: return "Rock solid"
        case 55..<80: return "Going strong"
        case 30..<55: return "Finding your rhythm"
        default: return "Just getting started"
        }
    }

    // MARK: - Messages

    /// A celebration message when a partner hits a streak milestone, else nil (no spam on
    /// non-milestone days). Milestones: 3, 7, 14, 30, 50, 100, then every 100.
    static func celebrationMessage(forStreak streak: Int) -> String? {
        let milestones: Set<Int> = [3, 7, 14, 30, 50, 100]
        let isMilestone = milestones.contains(streak) || (streak > 100 && streak % 100 == 0)
        guard isMilestone else { return nil }
        return "🎉 \(streak)-day streak! That consistency is something to be proud of."
    }

    /// A small set of ready-to-send encouragements the user can tap to support a partner.
    static func suggestedEncouragements() -> [String] {
        [
            "You've got this 💪",
            "Proud of you for showing up.",
            "One small step today is enough.",
            "Rooting for you!",
            "Today's a fresh start — go gently.",
        ]
    }
}
