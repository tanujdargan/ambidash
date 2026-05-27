import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var title = ""
    @State private var subtitle = ""
    @State private var selectedDomain: GoalDomain = .body
    @State private var selectedHorizon: GoalHorizon = .now
    @State private var newGoal: Goal?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Goal")
                            TextField("What do you want to achieve?", text: $title)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink)
                            t.rule.frame(height: 1)
                        }

                        // Subtitle
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Context (optional)")
                            TextField("e.g. 17.8% bf now · target 14%", text: $subtitle)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(t.ink2)
                            t.rule.frame(height: 1)
                        }

                        // Pillar
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Pillar")
                            VStack(spacing: 6) {
                                ForEach(GoalDomain.allCases) { domain in
                                    let isSelected = selectedDomain == domain
                                    Button {
                                        Haptics.selection()
                                        selectedDomain = domain
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: domain.icon)
                                                .font(.system(size: 14))
                                                .foregroundStyle(isSelected ? t.accent : t.muted)
                                                .frame(width: 20)
                                            Text(domain.displayName)
                                                .font(.system(size: 14))
                                                .foregroundStyle(t.ink)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(t.accent)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? t.accent.opacity(0.08) : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? t.accent.opacity(0.3) : t.hair, lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Horizon
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Time horizon")
                            HStack(spacing: 8) {
                                ForEach(GoalHorizon.allCases) { horizon in
                                    let isSelected = selectedHorizon == horizon
                                    Button {
                                        Haptics.selection()
                                        selectedHorizon = horizon
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(horizon.dotColor)
                                                .frame(width: 8, height: 8)
                                            Text(horizon.displayName)
                                                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                                                .foregroundStyle(isSelected ? t.ink : t.muted)
                                            Text(horizon.timeframe)
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundStyle(t.faint)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? t.ink.opacity(0.08) : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? t.ink : t.hair, lineWidth: isSelected ? 1 : 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                }
            }
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
        Haptics.success()
        let priority = (profile.goals.count) + 1
        let goal = Goal(title: title, domain: selectedDomain, priority: priority)
        goal.subtitle = subtitle
        goal.horizon = selectedHorizon
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
