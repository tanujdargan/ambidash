import SwiftUI
import SwiftData

struct MentorMatchingView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var activeGoals: [Goal]

    private var profile: UserProfile? { profiles.first }

    private var myCode: String {
        guard let profile else { return "" }
        return ReferralService.ensureCode(for: profile, context: modelContext)
    }

    private var myDomains: [String] {
        activeGoals.map(\.domainRaw)
    }

    @State private var mentors: [[String: Any]] = []
    @State private var activeMatch: [String: Any]?
    @State private var isLoading = false
    @State private var requestedCodes: Set<String> = []

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let match = activeMatch {
                        activeMatchCard(match, t)
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if mentors.isEmpty && activeMatch == nil {
                        emptyState(t)
                    } else if activeMatch == nil {
                        availableMentorsSection(t)
                    }
                }
                .padding(22)
            }
            .background(t.bg)
            .navigationTitle("Find a Mentor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Active match

    @ViewBuilder
    private func activeMatchCard(_ match: [String: Any], _ t: ResolvedTheme) -> some View {
        let isMentee = (match["mentee_code"] as? String) == myCode
        let partnerCode = (isMentee ? match["mentor_code"] : match["mentee_code"]) as? String ?? "—"

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(t.accent)
                Text(isMentee ? "Your Mentor" : "Your Mentee")
                    .font(t.heading(17))
                    .foregroundStyle(t.ink)
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(t.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: isMentee ? "person.fill" : "graduationcap.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(t.accent)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(partnerCode)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.ink)
                    Text(isMentee ? "Guiding your progress" : "Learning from you")
                        .font(.caption)
                        .foregroundStyle(t.muted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: - Available mentors

    @ViewBuilder
    private func availableMentorsSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Mentors")
                .font(t.heading(17))
                .foregroundStyle(t.ink)

            ForEach(Array(mentors.enumerated()), id: \.offset) { _, mentor in
                mentorCard(mentor, t)
            }
        }
    }

    @ViewBuilder
    private func mentorCard(_ mentor: [String: Any], _ t: ResolvedTheme) -> some View {
        let code = mentor["code"] as? String ?? "—"
        let days = mentor["progress_days"] as? Int ?? 0
        let domains = (mentor["goal_domains"] as? [String]) ?? []
        let requested = requestedCodes.contains(code)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(t.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(t.accent)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(code)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.ink)
                    Text("\(days) days of progress")
                        .font(.caption)
                        .foregroundStyle(t.muted)
                }
                Spacer()
            }

            if !domains.isEmpty {
                let matched = domains.filter { myDomains.contains($0) }
                let labels = matched.isEmpty ? domains : matched
                HStack(spacing: 6) {
                    ForEach(labels.prefix(4), id: \.self) { raw in
                        let domain = GoalDomain(rawValue: raw)
                        Text(domain?.displayName ?? raw)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(matched.contains(raw) ? t.accent : t.muted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(matched.contains(raw) ? t.accentSoft : t.sunken)
                            .clipShape(Capsule())
                    }
                }
            }

            Button {
                Haptics.light()
                requestedCodes.insert(code)
                Task {
                    await SupabaseService.shared.requestMentorMatch(
                        menteeCode: myCode,
                        mentorCode: code
                    )
                }
            } label: {
                Text(requested ? "Request sent" : "Request match")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(requested ? t.muted : t.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(requested ? t.sunken : t.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(requested)
        }
        .padding(14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundStyle(t.faint)
            Text("No mentors available yet — keep showing up and you'll unlock mentoring others at 30 days.")
                .font(t.body(14))
                .foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        activeMatch = await SupabaseService.shared.fetchMyMentorMatch(code: myCode)
        let fetched = await SupabaseService.shared.fetchAvailableMentors(myDomains: myDomains) ?? []
        mentors = fetched.filter { ($0["code"] as? String) != myCode }
    }
}
