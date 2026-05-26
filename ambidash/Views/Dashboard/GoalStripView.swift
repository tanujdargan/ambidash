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
            .padding(.horizontal, AmbidashTheme.spacingMD)
        }
    }
}

private struct GoalChip: View {
    let goal: Goal

    private var statusColor: Color {
        switch goal.computedStatus {
        case .onTrack: AmbidashTheme.statusGood
        case .needsAttention: AmbidashTheme.statusWarn
        case .slipping: AmbidashTheme.statusBad
        case .paused: AmbidashTheme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent border
            Rectangle()
                .fill(AmbidashTheme.dimensionColor(for: goal.domain.dimension))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AmbidashTheme.textPrimary)
                    .lineLimit(1)

                Text(GoalHealthService.summaryText(for: goal))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AmbidashTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                .stroke(AmbidashTheme.border, lineWidth: 0.5)
        )
    }
}
