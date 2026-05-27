import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]
    @State private var showAddGoal = false

    private var profile: UserProfile? { profiles.first }
    private var goals: [Goal] { (profile?.goals ?? []).sorted { $0.priority < $1.priority } }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                if goals.isEmpty {
                    emptyState(t)
                } else {
                    goalContent(t)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(t.ink)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
            }
        }
    }

    @ViewBuilder
    private func goalContent(_ t: ResolvedTheme) -> some View {
        let active = goals.filter(\.isActive)
        let retired = goals.filter { !$0.isActive }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR GOALS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(t.muted)

                    Text("As you've named them.")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .tracking(-0.3)
                        .foregroundStyle(t.ink)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 14)

                // Grouped by horizon
                ForEach(GoalHorizon.allCases, id: \.self) { horizon in
                    let horizonGoals = active.filter { $0.horizon == horizon }
                    if !horizonGoals.isEmpty {
                        horizonSection(horizon, goals: horizonGoals, t: t)
                    }
                }

                // Quietly retired
                if !retired.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionLabel(title: "Quietly retired")
                            Spacer()
                            Text("\(retired.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(retired) { goal in
                                NavigationLink(value: goal.id) {
                                    goalRow(goal, dotColor: t.faint, t: t, retired: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }

                // Mentor card
                if active.count > 3 {
                    mentorCard(activeCount: active.count, retiredCount: retired.count, t: t)
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                }
            }
            .padding(.bottom, 100)
            .navigationDestination(for: UUID.self) { goalId in
                if let goal = goals.first(where: { $0.id == goalId }) {
                    GoalDetailView(goal: goal)
                }
            }
        }
    }

    @ViewBuilder
    private func horizonSection(_ horizon: GoalHorizon, goals: [Goal], t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle().fill(horizon.dotColor).frame(width: 6, height: 6)
                    SectionLabel(title: horizon.displayName)
                }
                Text("· \(horizon.timeframe)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                Spacer()
                Text("\(goals.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(goals) { goal in
                    NavigationLink(value: goal.id) {
                        goalRow(goal, dotColor: horizon.dotColor, t: t)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, dotColor: Color, t: ResolvedTheme, retired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(goal.title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .strikethrough(retired, color: t.faint)
                .foregroundStyle(retired ? t.faint : t.ink)

            if !goal.subtitle.isEmpty {
                Text(goal.subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            } else {
                Text(GoalHealthService.summaryText(for: goal))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            }

            if !retired {
                let progress = min(1.0, max(0.05, 1.0 - Double(goal.neglectDays) / 14.0))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1).fill(t.hair)
                        RoundedRectangle(cornerRadius: 1).fill(t.ink).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 2)
                .frame(maxWidth: 200, alignment: .leading)
            }
        }
        .opacity(retired ? 0.45 : 1)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { t.hair.frame(height: 0.5) }
    }

    @ViewBuilder
    private func mentorCard(activeCount: Int, retiredCount: Int, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\"You have \(activeCount) active goals. The honest number you can act on this week is two, maybe three. Pick them — I won't decide for you.\"")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(t.ink)

            Text("— Mentor, every Sunday")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.muted)
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 16) {
            Text("No goals yet.")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)
            Text("Tap + to name what matters.")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
        }
    }
}
