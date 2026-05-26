import SwiftUI
import SwiftData

struct PriorityListView: View {
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(indexColor(for: action, index: index))
                            .frame(width: 28, height: 28)

                        if action.statusRaw == "done" {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        } else if action.statusRaw == "skipped" {
                            Image(systemName: "forward.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AmbidashTheme.textSecondary)
                        }
                    }
                    .padding(.top, 6)

                    ActionRow(
                        action: action,
                        onDone: { onDone(action) },
                        onSkip: { onSkip(action) }
                    )
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

    private func indexColor(for action: PlannedAction, index: Int) -> Color {
        switch action.statusRaw {
        case "done": return AmbidashTheme.statusGood
        case "skipped": return AmbidashTheme.statusWarn
        default:
            return AmbidashTheme.bgElevated
        }
    }
}
