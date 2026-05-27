import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var title = ""
    @State private var selectedDomain: GoalDomain = .body
    @State private var newGoal: Goal?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("What do you want to achieve?", text: $title)
                        .foregroundStyle(t.ink)

                    Picker("Domain", selection: $selectedDomain) {
                        ForEach(GoalDomain.allCases) { domain in
                            Label(domain.displayName, systemImage: domain.icon)
                                .tag(domain)
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section {
                    Text("Mapped to: \(selectedDomain.dimension.displayName) dimension")
                        .font(.caption)
                        .foregroundStyle(t.muted)
                }
                .listRowBackground(t.surface)
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $newGoal) { goal in
                DomainAssessmentSheet(
                    goal: goal,
                    questions: DomainAssessmentQuestions.questions(for: goal.domain)
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGoal()
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
        try? modelContext.save()

        let questions = DomainAssessmentQuestions.questions(for: selectedDomain)
        if !questions.isEmpty {
            newGoal = goal
        } else {
            dismiss()
        }
    }
}
