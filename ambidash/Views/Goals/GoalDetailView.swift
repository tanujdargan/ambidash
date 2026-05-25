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
                        Text(goal.domain.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Status") {
                LabeledContent("Health", value: goal.computedStatus.label)
                LabeledContent("Days since progress", value: "\(goal.neglectDays)")
                LabeledContent("Priority", value: "\(goal.priority)")
                LabeledContent("Created", value: goal.createdAt.formatted(.dateTime.month().day().year()))

                if let streak = goal.streak {
                    LabeledContent("Current streak", value: "\(streak.currentCount) days")
                    LabeledContent("Best streak", value: "\(streak.bestCount) days")
                }
            }

            Section {
                Button(goal.isActive ? "Pause Goal" : "Resume Goal") {
                    goal.isActive.toggle()
                }

                Button("Log Progress") {
                    goal.lastProgressDate = .now
                    goal.streak?.recordActivity()
                }
                .tint(.green)
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
