import SwiftUI
import SwiftData

struct FocusBlocksView: View {
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(actions) { action in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(borderColor(for: action))
                        .frame(width: 4)
                        .padding(.trailing, 12)

                    VStack(alignment: .leading, spacing: 2) {
                        if !action.timeSlot.isEmpty {
                            Text(action.timeSlot)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                        }

                        ActionRow(
                            action: action,
                            onDone: { onDone(action) },
                            onSkip: { onSkip(action) }
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func borderColor(for action: PlannedAction) -> Color {
        switch action.statusRaw {
        case "done": return .green
        case "skipped": return .orange
        default: return .blue
        }
    }
}
