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
                Text("Focus on this now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(completedCount)/\(actions.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(action.title)
                    .font(.title2.weight(.bold))

                Label("\(action.durationMinutes) minutes", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !action.whyReasoning.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this matters")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        Text(action.whyReasoning)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 16) {
                Button(action: { onDone(action) }) {
                    Label("Mark Done", systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: { onSkip(action) }) {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var completionSummary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All done for today!")
                .font(.title2.weight(.bold))

            Text("You completed \(completedCount) action\(completedCount == 1 ? "" : "s"). Great work.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
