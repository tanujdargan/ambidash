import SwiftUI
import SwiftData

struct PriorityListView: View {
    @Environment(ThemeManager.self) private var tm
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        let t = tm.resolved
        LazyVStack(spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(indexColor(for: action, index: index, t: t))
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
                                .foregroundStyle(t.muted)
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
                .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(t.hair, lineWidth: 0.5)
                )
            }
        }
    }

    private func indexColor(for action: PlannedAction, index: Int, t: ResolvedTheme) -> Color {
        switch action.statusRaw {
        case "done": return t.ok
        case "skipped": return t.accent
        default:
            return t.surface
        }
    }
}
