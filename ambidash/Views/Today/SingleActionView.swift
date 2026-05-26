import SwiftUI
import SwiftData

struct SingleActionView: View {
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("RIGHT NOW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AmbidashTheme.accent)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                Text("\(completedCount)/\(actions.count) done")
                    .font(.caption)
                    .foregroundStyle(AmbidashTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(action.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AmbidashTheme.textPrimary)

                Label("\(action.durationMinutes) minutes", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(AmbidashTheme.textSecondary)

                if !action.whyReasoning.isEmpty {
                    Divider()
                        .background(AmbidashTheme.border)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this matters")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AmbidashTheme.textTertiary)
                            .textCase(.uppercase)

                        Text(action.whyReasoning)
                            .font(.body)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(spacing: 10) {
                AccentButton("Mark Done", icon: "checkmark.circle.fill") {
                    onDone(action)
                }
                GhostButton(title: "Skip") {
                    onSkip(action)
                }
            }
        }
        .padding(AmbidashTheme.spacingMD)
        .background(AmbidashTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge)
                .stroke(AmbidashTheme.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var completionSummary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AmbidashTheme.statusGood)

            Text("All done for today!")
                .font(.title2.weight(.bold))
                .foregroundStyle(AmbidashTheme.textPrimary)

            Text("You completed \(completedCount) action\(completedCount == 1 ? "" : "s"). Great work.")
                .font(.body)
                .foregroundStyle(AmbidashTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AmbidashTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge)
                .stroke(AmbidashTheme.border, lineWidth: 0.5)
        )
    }
}
