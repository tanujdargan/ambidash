import SwiftUI

/// A horizontally scrolling strip of horizon-colored goal chips. Each chip
/// drills into `GoalDetailView` (so the per-goal 14-day sparkline + roadmap it
/// hosts is reachable from the dashboard). Must be rendered inside a
/// `NavigationStack` for the push to resolve.
struct GoalStripView: View {
    let goals: [Goal]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        GoalChip(goal: goal)
                    }
                    .buttonStyle(.scalePress)
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
                StatusDot(status: goal.computedStatus)
                    .scaleEffect(0.6)
                    .frame(width: 5, height: 5)
            }

            Text(goal.subtitle.isEmpty ? GoalHealthService.summaryText(for: goal) : goal.subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(t.muted)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(t.hair, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
