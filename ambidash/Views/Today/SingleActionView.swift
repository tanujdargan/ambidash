import SwiftUI
import SwiftData

struct SingleActionView: View {
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    @Environment(ThemeManager.self) private var tm

    private var currentAction: PlannedAction? {
        actions.first { $0.statusRaw == "pending" }
    }

    private var completedCount: Int {
        actions.filter { $0.statusRaw == "done" }.count
    }

    private var allDone: Bool {
        !actions.isEmpty && actions.allSatisfy { $0.statusRaw != "pending" }
    }

    var body: some View {
        if allDone {
            completionSummary
        } else if let action = currentAction {
            actionCard(action)
        }
    }

    @ViewBuilder
    private func actionCard(_ action: PlannedAction) -> some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("RIGHT NOW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(t.accent)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                Text("\(completedCount)/\(actions.count) done")
                    .font(.caption)
                    .foregroundStyle(t.muted)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(action.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(t.ink)

                Label("\(action.durationMinutes) minutes", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(t.muted)

                if !action.whyReasoning.isEmpty {
                    Divider()
                        .background(t.hair)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this matters")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(t.faint)
                            .textCase(.uppercase)

                        Text(action.whyReasoning)
                            .font(.body)
                            .foregroundStyle(t.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(spacing: 10) {
                AccentButton(label: "Mark Done") {
                    onDone(action)
                }
                GhostButton(label: "Skip") {
                    onSkip(action)
                }
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var completionSummary: some View {
        let t = tm.resolved
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(t.ok)

            Text("All done for today!")
                .font(.title2.weight(.bold))
                .foregroundStyle(t.ink)

            Text("You completed \(completedCount) action\(completedCount == 1 ? "" : "s"). Great work.")
                .font(.body)
                .foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }
}
