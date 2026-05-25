import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var title = ""
    @State private var selectedDomain: GoalDomain = .fitness

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("What do you want to achieve?", text: $title)

                    Picker("Domain", selection: $selectedDomain) {
                        ForEach(GoalDomain.allCases) { domain in
                            Label(domain.displayName, systemImage: domain.icon)
                                .tag(domain)
                        }
                    }
                }

                Section {
                    Text("Mapped to: \(selectedDomain.dimension.displayName) dimension")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGoal()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addGoal() {
        guard let profile else { return }
        let priority = (profile.goals.count) + 1
        let goal = Goal(title: title, domain: selectedDomain, priority: priority)
        goal.streak = Streak()
        profile.goals.append(goal)
    }
}
