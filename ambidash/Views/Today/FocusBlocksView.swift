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
                                .foregroundStyle(AmbidashTheme.textTertiary)
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
                .background(AmbidashTheme.bgCard, in: RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                        .stroke(AmbidashTheme.border, lineWidth: 0.5)
                )
            }
        }
    }

    private func borderColor(for action: PlannedAction) -> Color {
        switch action.statusRaw {
        case "done": return AmbidashTheme.statusGood
        case "skipped": return AmbidashTheme.statusWarn
        default: return AmbidashTheme.accent
        }
    }
}
