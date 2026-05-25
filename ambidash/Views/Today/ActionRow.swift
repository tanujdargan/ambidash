import SwiftUI
import SwiftData

struct ActionRow: View {
    @Bindable var action: PlannedAction
    var onDone: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .strikethrough(action.statusRaw == "done")
                        .foregroundStyle(action.statusRaw == "pending" ? .primary : .secondary)

                    Text("\(action.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge
            }

            if !action.whyReasoning.isEmpty {
                Text(action.whyReasoning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if action.statusRaw == "pending" {
                HStack(spacing: 12) {
                    Button(action: onDone) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch action.statusRaw {
        case "done":
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case "skipped":
            Label("Skipped", systemImage: "forward.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }
}
