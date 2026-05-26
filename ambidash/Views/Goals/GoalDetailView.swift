import SwiftUI

struct GoalDetailView: View {
    @Bindable var goal: Goal

    var body: some View {
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
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Text(goal.domain.displayName)
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)
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
            .listRowBackground(AmbidashTheme.bgCard)

            Section {
                Button(goal.isActive ? "Pause Goal" : "Resume Goal") {
                    goal.isActive.toggle()
                }

                Button("Log Progress") {
                    goal.lastProgressDate = .now
                    goal.streak?.recordActivity()
                }
                .tint(AmbidashTheme.statusGood)
            }
            .listRowBackground(AmbidashTheme.bgCard)
        }
        .scrollContentBackground(.hidden)
        .background(AmbidashTheme.bgBase)
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
