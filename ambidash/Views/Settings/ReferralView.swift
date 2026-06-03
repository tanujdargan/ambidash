import SwiftUI
import SwiftData

/// v4 #11 — the referral screen. Ambidash is invite-only; this makes sharing your
/// code frictionless and the milestone rewards visible. Your code + QR + share link
/// up top, a one-time "joined via a friend" redeem flow, and a tier ladder driven by
/// confirmed referrals. Logic lives in ReferralService; this is the shell.
struct ReferralView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    @State private var enteredCode = ""
    @State private var redeemError: String?

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    yourCodeSection(t)
                    t.hair.frame(height: 0.5)
                    rewardsSection(t)
                    t.hair.frame(height: 0.5)
                    redeemSection(t)
                }
                .padding(22)
            }
            .background(t.bg)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { ReferralService.ensureCode(for: profile, context: modelContext) }
        .accessibilityIdentifier("referral.sheet")
    }

    // MARK: - Your code

    @ViewBuilder
    private func yourCodeSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Your invite code")
            Text("Ambidash grows by invite only. Share your code — when a friend joins with it, you both move up the circle.")
                .font(t.body(13))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !profile.referralCode.isEmpty {
                Text(profile.referralCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(t.ink)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("referral.code")
            }

            if let qr = QRCode.image(from: profile.referralCode) {
                qr.resizable()
                    .frame(width: 150, height: 150)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ShareLink(item: ReferralService.shareText(code: profile.referralCode)) {
                Label("Share invite", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(t.bg)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(t.accent)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("referral.share")
        }
    }

    // MARK: - Rewards ladder

    @ViewBuilder
    private func rewardsSection(_ t: ResolvedTheme) -> some View {
        let count = profile.referralCount
        let current = ReferralService.tier(for: count)
        let next = ReferralService.nextTier(for: count)

        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Your circle")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(count)")
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(t.ink)
                Text(count == 1 ? "friend joined" : "friends joined")
                    .font(t.body(14))
                    .foregroundStyle(t.muted)
            }
            .accessibilityIdentifier("referral.count")

            if let next {
                Text("\(next.remaining) more to reach \(next.tier.title) — \(next.tier.perk)")
                    .font(t.body(13))
                    .foregroundStyle(t.accent)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("You've reached the top — \(current.title). Thank you for growing Ambidash.")
                    .font(t.body(13))
                    .foregroundStyle(t.accent)
            }

            VStack(spacing: 8) {
                ForEach(ReferralTier.allCases.filter { $0 != .none }, id: \.self) { tier in
                    tierRow(tier, earned: count >= tier.threshold, t: t)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func tierRow(_ tier: ReferralTier, earned: Bool, t: ResolvedTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: earned ? "checkmark.seal.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(earned ? t.ok : t.faint)
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(earned ? t.ink : t.muted)
                Text(tier.perk)
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("\(tier.threshold)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(t.faint)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Redeem

    @ViewBuilder
    private func redeemSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Were you invited?")

            if profile.referredByCode.isEmpty {
                Text("Enter a friend's code to claim your welcome perk.")
                    .font(t.body(13))
                    .foregroundStyle(t.muted)

                HStack(spacing: 10) {
                    TextField("Their code", text: $enteredCode)
                        .font(.system(size: 15, design: .monospaced))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalizationIfAvailable()
                        .submitLabel(.go)
                        .onSubmit { redeem() }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(t.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("referral.redeemField")
                    Button("Redeem") { redeem() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(enteredCode.isEmpty ? t.faint : t.bg)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(enteredCode.isEmpty ? t.sunken : t.accent)
                        .clipShape(Capsule())
                        .disabled(enteredCode.isEmpty)
                }

                if let redeemError {
                    Text(redeemError)
                        .font(t.body(12))
                        .foregroundStyle(t.danger)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(t.ok)
                    Text("Joined via \(profile.referredByCode) — welcome perk claimed.")
                        .font(t.body(13)).foregroundStyle(t.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("referral.redeemedState")
            }
        }
    }

    private func redeem() {
        let result = ReferralService.redeem(code: enteredCode, profile: profile, context: modelContext)
        switch result {
        case .ok:
            Haptics.success()
            redeemError = nil
            enteredCode = ""
        case .empty:
            redeemError = "Enter a code first."
        case .ownCode:
            redeemError = "That's your own code."
        case .alreadyRedeemed:
            redeemError = "You've already claimed a welcome perk."
        }
    }
}

private extension View {
    @ViewBuilder func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func textInputAutocapitalizationIfAvailable() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.characters)
        #else
        self
        #endif
    }
}
