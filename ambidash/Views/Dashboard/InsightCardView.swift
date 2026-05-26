// ambidash/Views/Dashboard/InsightCardView.swift
import SwiftUI

struct InsightCardView: View {
    let goals: [Goal]
    let snapshot: IntegrationSnapshot?

    @State private var insight: String?
    @State private var isLoading = false
    @State private var hasAttempted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PATTERN SPOTTED")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
                .tracking(0.5)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing your patterns...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let insight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } else if !AIConfig.isConfigured {
                Text("Set your Anthropic API key in Settings to unlock AI-powered insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to generate an insight about your patterns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
