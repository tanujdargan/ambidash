import SwiftUI

struct GoalStripView: View {
    let goals: [Goal]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(goals) { goal in
                    GoalChip(goal: goal)
                }
            }
            .padding(.horizontal, 22)
        }
    }
}

private struct GoalChip: View {
    let goal: Goal
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(goal.horizon.dotColor)
                    .frame(width: 5, height: 5)
                Text(goal.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(t.ink)
                    .lineLimit(1)
            }

            Text(goal.subtitle.isEmpty ? GoalHealthService.summaryText(for: goal) : goal.subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(t.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }
}
