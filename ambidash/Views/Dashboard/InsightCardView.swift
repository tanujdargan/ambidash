// ambidash/Views/Dashboard/InsightCardView.swift
import SwiftUI

struct InsightCardView: View {
    let goals: [Goal]
    let snapshot: IntegrationSnapshot?

    @Environment(ThemeManager.self) private var tm
    @State private var insight: String?
    @State private var isLoading = false
    @State private var hasAttempted = false

    var body: some View {
        let t = tm.resolved
        HStack(spacing: 0) {
            // Left accent border
            Rectangle()
                .fill(t.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("PATTERN SPOTTED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(t.accent)
                    .tracking(1.2)

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(t.accent)
                        Text("Analyzing your patterns...")
                            .font(.subheadline)
                            .foregroundStyle(t.muted)
                    }
                } else if let insight {
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(t.ink)
                } else if !AIConfig.isConfigured {
                    Text("Set your Anthropic API key in Settings to unlock AI-powered insights.")
                        .font(.subheadline)
                        .foregroundStyle(t.muted)
                } else {
                    Text("Tap to generate an insight about your patterns.")
                        .font(.subheadline)
                        .foregroundStyle(t.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.hair, lineWidth: 0.5)
        )
        .accessibilityLabel(insight != nil ? "AI Insight: \(insight!)" : "Tap to generate an AI insight")
        .onTapGesture {
            if !isLoading && AIConfig.isConfigured {
                Task { await fetchInsight() }
            }
        }
        .task {
            if AIConfig.isConfigured && !hasAttempted {
                await fetchInsight()
            }
        }
    }

    private func fetchInsight() async {
        guard NetworkMonitor.shared.isConnected else {
            insight = "No internet connection. Insights require a network connection."
            return
        }

        guard PremiumGateService.canFetchInsight() else {
            insight = "You've used your free insight for today. Upgrade to Premium for unlimited insights."
            return
        }

        isLoading = true
        hasAttempted = true
        defer { isLoading = false }

        let capturedGoals = goals
        let capturedSnapshot = snapshot
        let streakInfo = capturedGoals.compactMap { goal -> String? in
            guard let streak = goal.streak, streak.currentCount > 0 else { return nil }
            return "\(goal.title): \(streak.currentCount)d"
        }.joined(separator: ", ")

        do {
            insight = try await AIService.generateInsight(goals: capturedGoals, snapshot: capturedSnapshot, streakSummary: streakInfo)
            PremiumGateService.recordInsightFetch()
        } catch {
            insight = nil
        }
    }
}
