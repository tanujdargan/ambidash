// ambidash/Views/Reflect/HonestMirrorView.swift
import SwiftUI

struct HonestMirrorView: View {
    let plan: DailyPlan?
    let mood: String
    let blockers: [String]

    @Environment(ThemeManager.self) private var tm
    @State private var feedback: String?
    @State private var isLoading = false

    var body: some View {
        let t = tm.resolved
        if PremiumGateService.canUseHonestMirror() {
            if AIConfig.isConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HONEST MIRROR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(t.danger)
                            .tracking(1.2)
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(t.muted)
                        }
                    }

                    if let feedback {
                        Text(feedback)
                            .font(.subheadline)
                            .foregroundStyle(t.ink)
                            .lineSpacing(2)
                    } else if !isLoading {
                        Text("Tap to get honest feedback on your day.")
                            .font(.subheadline)
                            .foregroundStyle(t.muted)
                    }
                }
                .padding()
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(t.danger.opacity(0.4), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(t.danger)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
                .onTapGesture {
                    if !isLoading { Task { await fetchFeedback() } }
                }
            }
        } else {
            let t2 = tm.resolved
            VStack(alignment: .leading, spacing: 6) {
                Text("HONEST MIRROR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(t2.danger)
                    .tracking(1.2)
                Text("Upgrade to Premium for AI-powered honest feedback on your day.")
                    .font(.subheadline)
                    .foregroundStyle(t2.muted)
            }
            .padding()
            .background(t2.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(t2.hair, lineWidth: 0.5)
            )
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
