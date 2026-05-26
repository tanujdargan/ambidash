import SwiftUI

struct GoalDetailView: View {
    @Environment(ThemeManager.self) private var tm
    @Bindable var goal: Goal

    var body: some View {
        let t = tm.resolved
        List {
            Section {
                HStack {
                    Image(systemName: goal.domain.icon)
                        .font(.title)
                        .foregroundStyle(goal.computedStatus.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(t.ink)
                        Text(goal.domain.displayName)
                            .font(.caption)
                            .foregroundStyle(t.muted)
                    }
                }
                .listRowBackground(t.surface)
            }

            Section("Status") {
                LabeledContent("Health", value: goal.computedStatus.label)
                    .foregroundStyle(goal.computedStatus.color)
                LabeledContent("Days since progress", value: "\(goal.neglectDays)")
                LabeledContent("Priority", value: "\(goal.priority)")
                LabeledContent("Created", value: goal.createdAt.formatted(.dateTime.month().day().year()))

                if let streak = goal.streak {
                    LabeledContent("Current streak", value: "\(streak.currentCount) days")
                    LabeledContent("Best streak", value: "\(streak.bestCount) days")
                }
            }
            .listRowBackground(t.surface)

            Section {
                Button(goal.isActive ? "Pause Goal" : "Resume Goal") {
                    goal.isActive.toggle()
                }

                Button("Log Progress") {
                    goal.lastProgressDate = .now
                    goal.streak?.recordActivity()
                }
                .tint(t.ok)
            }
            .listRowBackground(t.surface)
        }
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
