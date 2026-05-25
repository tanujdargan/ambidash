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
                                .foregroundStyle(.white)
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
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func indexColor(for action: PlannedAction, index: Int) -> Color {
        switch action.statusRaw {
        case "done": return .green
        case "skipped": return .orange
        default:
            switch index {
            case 0: return .red
            case 1: return .orange
            case 2: return .yellow
            default: return .blue
            }
        }
    }
}
