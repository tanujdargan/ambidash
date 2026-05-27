import SwiftUI

struct InsightCardView: View {
    let goals: [Goal]
    let snapshot: IntegrationSnapshot?

    @Environment(ThemeManager.self) private var tm
    @State private var insight: String?
    @State private var isLoading = false
    @State private var hasAttempted = false

    private var localInsight: String {
        let active = goals.filter(\.isActive)
        guard !active.isEmpty else { return "Add some goals to get started." }

        let mostNeglected = active.max(by: { $0.neglectDays < $1.neglectDays })
        let dimensions = DimensionScoreCalculator.scores(from: active, snapshot: snapshot)
        let lowestDim = dimensions.min(by: { $0.value < $1.value })

        if let neglected = mostNeglected, neglected.neglectDays > 7 {
            return "\(neglected.title) hasn't moved in \(neglected.neglectDays) days. It's still on your list — is it still in your life?"
        } else if let lowest = lowestDim {
            return "\(lowest.key.fullName) is your lowest vital this week. One action today would shift it."
        } else {
            return "You're steady across all vitals. Pick the one that matters most this week and push it."
        }
    }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Mentor surfaced")

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(t.accent)
                    Text("Thinking...")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(t.muted)
                }
            } else {
                Text(insight ?? localInsight)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(3)
                    .foregroundStyle(t.ink)
            }

            if AIConfig.isConfigured && insight == nil && !isLoading {
                HStack(spacing: 8) {
                    PillButton(label: "Ask Mentor", primary: true) {
                        Task { await fetchInsight() }
                    }
                }
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityLabel("Mentor insight: \(insight ?? localInsight)")
        .task {
            if AIConfig.isConfigured && !hasAttempted {
                await fetchInsight()
            }
        }
    }

    private func fetchInsight() async {
        guard NetworkMonitor.shared.isConnected else {
            insight = "No connection — showing local patterns instead."
            return
        }
        guard PremiumGateService.canFetchInsight() else {
            return
        }

        isLoading = true
        hasAttempted = true
        defer { isLoading = false }

        let streakInfo = goals.compactMap { goal -> String? in
            guard let streak = goal.streak, streak.currentCount > 0 else { return nil }
            return "\(goal.title): \(streak.currentCount)d"
        }.joined(separator: ", ")

        do {
            insight = try await AIService.generateInsight(goals: goals, snapshot: snapshot, streakSummary: streakInfo)
            PremiumGateService.recordInsightFetch()
        } catch {
            insight = nil
        }
    }
}
