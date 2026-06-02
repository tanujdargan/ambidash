import SwiftUI
import SwiftData

/// v4: DYNAMIC categories — the user never picks a category; categories emerge
/// from the goals they set. Active goals are grouped by their domain, and only
/// the domains that actually have goals appear (so a founder chasing funding sees
/// "Wealth & Freedom" surface, a student sees "Mind & Character", etc.). Each row
/// shows the goal count + the subgoal (milestone) count, making the goal→subgoal
/// hierarchy visible at a glance. Owns a small @Query for goals.
struct GoalCategoriesComponent: View {
    @Environment(ThemeManager.self) private var tm

    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.priority)
    private var goals: [Goal]

    /// Non-empty categories only, in the canonical domain order — DERIVED from
    /// whatever the user is actually working on.
    private var categories: [(domain: GoalDomain, goals: [Goal])] {
        let grouped = Dictionary(grouping: goals, by: { $0.domain })
        return GoalDomain.allCases.compactMap { d in
            guard let gs = grouped[d], !gs.isEmpty else { return nil }
            return (d, gs)
        }
    }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Categories")

            if categories.isEmpty {
                Text("Your categories appear here as you add goals — derived from what you're working on.")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
            } else {
                VStack(alignment: .leading, spacing: t.space.component) {
                    ForEach(categories, id: \.domain) { entry in
                        categoryRow(entry.domain, entry.goals, t)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("component.categories")
    }

    @ViewBuilder
    private func categoryRow(_ domain: GoalDomain, _ goals: [Goal], _ t: ResolvedTheme) -> some View {
        let subgoals = goals.reduce(0) { $0 + ($1.milestones?.count ?? 0) }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: domain.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(t.accent)
                    .frame(width: 18)
                Text(domain.displayName)
                    .font(t.heading(15))
                    .foregroundStyle(t.ink)
                Spacer(minLength: 4)
                Text(countLabel(goals: goals.count, subgoals: subgoals))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
            }
            ForEach(goals.prefix(3)) { g in
                Text("· \(g.title)")
                    .font(t.body(12))
                    .foregroundStyle(t.muted)
                    .lineLimit(1)
                    .padding(.leading, 26)
            }
        }
    }

    private func countLabel(goals: Int, subgoals: Int) -> String {
        let g = "\(goals) goal\(goals == 1 ? "" : "s")"
        return subgoals > 0 ? "\(g) · \(subgoals) sub" : g
    }
}
