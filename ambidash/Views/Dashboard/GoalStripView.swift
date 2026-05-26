import SwiftUI

struct GoalStripView: View {
    let goals: [Goal]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(goals) { goal in
                    GoalChip(goal: goal)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct GoalChip: View {
    let goal: Goal

    @Environment(ThemeManager.self) private var tm

    private func statusColor(_ t: ResolvedTheme) -> Color {
        switch goal.computedStatus {
        case .onTrack: t.ok
        case .needsAttention: t.accent
        case .slipping: t.danger
        case .paused: t.faint
        }
    }

    var body: some View {
        let t = tm.resolved
        HStack(spacing: 0) {
            // Left accent border
            Rectangle()
                .fill(AmbidashTheme.dimensionColor(for: goal.domain.dimension))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.ink)
                    .lineLimit(1)

                Text(GoalHealthService.summaryText(for: goal))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor(t))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }
}
