import SwiftUI
import SwiftData

struct GoalListView: View {
    @Query private var profiles: [UserProfile]
    @State private var showAddGoal = false

    private var goals: [Goal] {
        (profile?.goals ?? []).sorted { $0.priority < $1.priority }
    }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                let active = goals.filter(\.isActive)
                let paused = goals.filter { !$0.isActive }

                if !active.isEmpty {
                    Section {
                        ForEach(active) { goal in
                            NavigationLink(value: goal.id) {
                                GoalRow(goal: goal)
                            }
                            .listRowBackground(AmbidashTheme.bgCard)
                        }
                    } header: {
                        SectionHeader(title: "Active")
                    }
                }

                if !paused.isEmpty {
                    Section {
                        ForEach(paused) { goal in
                            NavigationLink(value: goal.id) {
                                GoalRow(goal: goal)
                            }
                            .listRowBackground(AmbidashTheme.bgCard)
                        }
                    } header: {
                        SectionHeader(title: "Paused")
                    }
                }
            }
            .listStyle(.plain)
            .background(AmbidashTheme.bgBase)
            .scrollContentBackground(.hidden)
            .navigationTitle("Goals")
            .navigationDestination(for: UUID.self) { goalId in
                if let goal = goals.first(where: { $0.id == goalId }) {
                    GoalDetailView(goal: goal)
                }
            }
            .toolbar {
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
            }
            .overlay {
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals Yet",
                        systemImage: "target",
                        description: Text("Tap + to add your first goal")
                    )
                }
            }
        }
    }
}

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.domain.icon)
                .foregroundStyle(goal.computedStatus.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.body)
                    .foregroundStyle(AmbidashTheme.textPrimary)
                Text(GoalHealthService.summaryText(for: goal))
                    .font(.caption)
                    .foregroundStyle(goal.computedStatus.color)
            }

            Spacer()

            if let streak = goal.streak, streak.currentCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(AmbidashTheme.statusWarn)
                    Text("\(streak.currentCount)")
                        .font(.caption)
                        .foregroundStyle(AmbidashTheme.textSecondary)
                }
            }
        }
    }
}
