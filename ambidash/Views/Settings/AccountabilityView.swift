// ambidash/Views/Settings/AccountabilityView.swift
//
// v5 feat/v5-social-accountability — the accountability partners screen. Pair with friends by
// exchanging invite codes (reusing the ReferralService code), opt specific goals into shared
// visibility, see each partner's daily check-in status + streak, send encouragement/celebration
// messages, and track your own accountability score. Local SwiftData is the source of truth; when
// Supabase is configured, check-ins + messages fan out in real time (best-effort).
import SwiftUI
import SwiftData

struct AccountabilityView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.priority) private var activeGoals: [Goal]
    @Query(sort: \AccountabilityPartner.createdAt) private var partners: [AccountabilityPartner]
    @Query private var messages: [EncouragementMessage]
    @Query private var actuals: [ActualEvent]
    @Query private var goalsForStreak: [Goal]

    @State private var showAddPartner = false

    private var profile: UserProfile? { profiles.first }

    /// The user's stable invite code (minted on first view).
    private var myCode: String {
        guard let profile else { return "" }
        return ReferralService.ensureCode(for: profile, context: modelContext)
    }

    /// The user's accountability score, derived from EXISTING data: distinct active days in the
    /// last week (showing up), their best current streak, and how many encouragements they've sent.
    private var myScore: Int {
        let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
        let activeDays = Set(
            actuals.filter { $0.date >= weekAgo && $0.completionStatus != .abandoned }
                .map { Calendar.current.startOfDay(for: $0.date) }
        ).count
        let bestStreak = StreakService.summary(for: goalsForStreak).longestCurrentStreak
        let sent = messages.filter(\.fromMe).count
        return AccountabilityLogic.score(checkInDays: activeDays, windowDays: 7, currentStreak: bestStreak, messagesSent: sent)
    }

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NavigationLink {
                    SocialFeedView().environment(tm)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(t.accent)
                        Text("Activity Feed")
                            .font(t.heading(15))
                            .foregroundStyle(t.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(t.faint)
                    }
                    .padding(16)
                    .background(t.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("accountability.feedLink")

                scoreCard(t)
                inviteCard(t)
                partnersSection(t)
                sharedGoalsSection(t)
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("Accountability")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("accountability.screen")
        .sheet(isPresented: $showAddPartner) {
            AddPartnerSheet(ownCode: myCode, existingCodes: partners.map(\.code))
                .environment(tm)
        }
    }

    // MARK: - Score

    @ViewBuilder
    private func scoreCard(_ t: ResolvedTheme) -> some View {
        let s = myScore
        VStack(alignment: .leading, spacing: 6) {
            Text("Your accountability score")
                .font(.caption).foregroundStyle(t.muted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(s)").font(t.heading(40)).foregroundStyle(t.ink)
                Text(AccountabilityLogic.scoreBand(s)).font(t.body(14)).foregroundStyle(t.accent)
            }
            Text("Built from showing up, your streak, and supporting your partners — it only ever grows from doing those.")
                .font(.caption).foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Invite

    @ViewBuilder
    private func inviteCard(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your invite code").font(.caption).foregroundStyle(t.muted)
            HStack {
                Text(myCode.isEmpty ? "—" : myCode)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(t.ink)
                Spacer()
                if !myCode.isEmpty {
                    ShareLink(item: ReferralService.shareText(code: myCode)) {
                        Image(systemName: "square.and.arrow.up").foregroundStyle(t.accent)
                    }
                }
            }
            Text("Share this with a friend so they can add you as a partner.")
                .font(.caption).foregroundStyle(t.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Partners

    @ViewBuilder
    private func partnersSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Partners").font(t.heading(17)).foregroundStyle(t.ink)
                Spacer()
                Button {
                    Haptics.light()
                    showAddPartner = true
                } label: {
                    Label("Add", systemImage: "plus").font(.system(size: 13, weight: .medium)).foregroundStyle(t.accent)
                }
            }
            if partners.isEmpty {
                Text("No partners yet. Add a friend by their invite code to keep each other going.")
                    .font(t.body(13)).foregroundStyle(t.muted)
            } else {
                ForEach(partners) { partner in
                    PartnerRow(partner: partner) { text, kind in
                        send(text: text, kind: kind, to: partner)
                    }
                    .environment(tm)
                }
                .onDelete(perform: deletePartners)
            }
        }
    }

    private func deletePartners(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(partners[i]) }
        try? modelContext.save()
    }

    private func send(text: String, kind: EncouragementKind, to partner: AccountabilityPartner) {
        let msg = EncouragementMessage(partnerCode: partner.code, text: text, fromMe: true, kindRaw: kind.rawValue)
        modelContext.insert(msg)
        partner.messagesSent += 1
        try? modelContext.save()
        Haptics.success()
        let from = myCode
        Task {
            await SupabaseService.shared.sendEncouragement(toCode: partner.code, fromCode: from, text: text, kind: kind.rawValue)
            await SupabaseService.shared.pushFeedEvent(code: from, kind: "encouragement", title: text)
        }
    }

    // MARK: - Shared goals

    @ViewBuilder
    private func sharedGoalsSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared goals").font(t.heading(17)).foregroundStyle(t.ink)
            Text("Choose which goals your partners can see. Everything stays private until you share it.")
                .font(.caption).foregroundStyle(t.muted)
            if activeGoals.isEmpty {
                Text("No active goals to share yet.").font(t.body(13)).foregroundStyle(t.muted)
            } else {
                ForEach(activeGoals) { goal in
                    Toggle(isOn: Binding(
                        get: { goal.isSharedWithPartners },
                        set: { goal.isSharedWithPartners = $0; try? modelContext.save() }
                    )) {
                        Text(goal.title).font(t.body(14)).foregroundStyle(t.ink).lineLimit(1)
                    }
                    .tint(t.accent)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(t.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Partner row

private struct PartnerRow: View {
    @Environment(ThemeManager.self) private var tm
    let partner: AccountabilityPartner
    let onSend: (String, EncouragementKind) -> Void

    var body: some View {
        let t = tm.resolved
        let checkedInToday = AccountabilityLogic.hasCheckedInToday(partner.lastCheckInDate)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.displayName.isEmpty ? partner.code : partner.displayName)
                        .font(t.heading(15)).foregroundStyle(t.ink)
                    Text(AccountabilityLogic.partnerStatusLabel(lastCheckIn: partner.lastCheckInDate))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(checkedInToday ? t.ok : t.muted)
                }
                Spacer()
                if partner.partnerStreak > 0 {
                    Label("\(partner.partnerStreak)", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(t.accent)
                }
            }
            HStack(spacing: 8) {
                if partner.status == .pending {
                    Text("Invite sent").font(.caption2).foregroundStyle(t.faint)
                }
                Spacer()
                Menu {
                    if let celebration = AccountabilityLogic.celebrationMessage(forStreak: partner.partnerStreak) {
                        Button(celebration) { onSend(celebration, .celebration) }
                    }
                    ForEach(AccountabilityLogic.suggestedEncouragements(), id: \.self) { text in
                        Button(text) { onSend(text, .encouragement) }
                    }
                } label: {
                    Label("Encourage", systemImage: "hand.thumbsup")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(t.accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add partner sheet

private struct AddPartnerSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let ownCode: String
    let existingCodes: [String]

    @State private var code = ""
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section {
                    Text("Enter your friend's invite code to pair up. You'll keep each other accountable with daily check-ins.")
                        .font(.footnote).foregroundStyle(t.muted)
                }
                .listRowBackground(t.surface)

                Section("Their invite code") {
                    TextField("AMBI-XXXXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                .listRowBackground(t.surface)

                Section("Their name (optional)") {
                    TextField("e.g. Sam", text: $name)
                }
                .listRowBackground(t.surface)

                if let error {
                    Text(error).font(.caption).foregroundStyle(t.danger)
                        .listRowBackground(t.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle("Add Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { add() } }
            }
        }
    }

    private func add() {
        switch AccountabilityLogic.validateInvite(code: code, ownCode: ownCode, existingPartnerCodes: existingCodes) {
        case .empty:
            error = "Enter an invite code."
        case .ownCode:
            error = "That's your own code — share it with a friend instead."
        case .alreadyPartner:
            error = "You're already partners with this code."
        case .valid(let normalized):
            let partner = AccountabilityPartner(code: normalized, displayName: name.trimmingCharacters(in: .whitespaces), statusRaw: "pending")
            modelContext.insert(partner)
            try? modelContext.save()
            Haptics.success()
            dismiss()
        }
    }
}
