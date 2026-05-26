// ambidash/Views/Reflect/HonestMirrorView.swift
import SwiftUI

struct HonestMirrorView: View {
    let plan: DailyPlan?
    let mood: String
    let blockers: [String]

    @State private var feedback: String?
    @State private var isLoading = false

    var body: some View {
        if PremiumGateService.canUseHonestMirror() {
            if AIConfig.isConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HONEST MIRROR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                            .tracking(0.5)
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let feedback {
                        Text(feedback)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(2)
                    } else if !isLoading {
                        Text("Tap to get honest feedback on your day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    if !isLoading { Task { await fetchFeedback() } }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("HONEST MIRROR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                    .tracking(0.5)
                Text("Upgrade to Premium for AI-powered honest feedback on your day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func fetchFeedback() async {
        isLoading = true
        defer { isLoading = false }

        let doneCount = plan?.actions.filter { $0.statusRaw == "done" }.count ?? 0
        let skippedCount = plan?.actions.filter { $0.statusRaw == "skipped" }.count ?? 0
        let totalCount = plan?.actions.count ?? 0
        let skippedTitles = plan?.actions.filter { $0.statusRaw == "skipped" }.map(\.title).joined(separator: ", ") ?? ""

        let prompt = """
        You are the "Honest Mirror" mentor in ambidash. Your job is to reflect reality without sugar-coating.

        USER'S DAY:
        - Mood self-assessment: "\(mood)"
        - Actions completed: \(doneCount) of \(totalCount)
        - Actions skipped: \(skippedCount) (\(skippedTitles))
        - Blockers reported: \(blockers.joined(separator: ", "))

        Give brutally honest feedback in 2-3 sentences. If they said "decent" but skipped half their actions, call that out. If they crushed it, acknowledge it briefly. Use loss framing — what did skipping cost them? Be direct. No pleasantries.
        """

        do {
            feedback = try await AIService.generateInsight(goals: [], snapshot: nil, streakSummary: prompt)
        } catch {
            feedback = nil
        }
    }
}
