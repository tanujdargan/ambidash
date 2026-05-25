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
            .padding(.horizontal)
        }
    }
}

private struct GoalChip: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goal.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(GoalHealthService.summaryText(for: goal))
                .font(.caption2)
                .foregroundStyle(goal.computedStatus.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
