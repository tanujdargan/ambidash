import SwiftUI
import SwiftData

struct FocusBlocksView: View {
    @Environment(ThemeManager.self) private var tm
    var actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        let t = tm.resolved
        LazyVStack(spacing: 12) {
            ForEach(actions) { action in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(borderColor(for: action, t: t))
                        .frame(width: 4)
                        .padding(.trailing, 12)

                    VStack(alignment: .leading, spacing: 2) {
                        if !action.timeSlot.isEmpty {
                            Text(action.timeSlot)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(t.faint)
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
                .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(t.hair, lineWidth: 0.5)
                )
            }
        }
    }

    private func borderColor(for action: PlannedAction, t: ResolvedTheme) -> Color {
        switch action.statusRaw {
        case "done": return t.ok
        case "skipped": return t.accent
        default: return t.accent
        }
    }
}
