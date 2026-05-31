import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var title = ""
    @State private var subtitle = ""
    @State private var details = ""
    @State private var selectedDomain: GoalDomain = .body
    @State private var selectedHorizon: GoalHorizon = .now
    @State private var selectedType: GoalType = .habit
    @State private var timesPerWeek = 3
    @State private var newGoal: Goal?

    // F2 — measurable target (collapsed by default; flow unchanged for non-numeric goals)
    @State private var metricEnabled = false
    @State private var baselineText = ""
    @State private var targetText = ""
    @State private var unitText = ""
    @State private var selectedDirection: MetricDirection = .increase

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

                        // Details — how you'll actually do it. This is the highest-
                        // leverage concreteness signal: it feeds both the AI prompt
                        // and the offline planner so goal-work becomes a real task
                        // ("45 min push/pull/legs at campus gym") instead of a nag.
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Details / how you'll do it (optional)")
                            TextField(
                                "e.g. push/pull/legs at campus gym, 45 min",
                                text: $details,
                                axis: .vertical
                            )
                            .lineLimit(2...5)
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

                        // Goal type (how it's pursued + judged)
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Goal type")
                            HStack(spacing: 6) {
                                ForEach(GoalType.allCases) { type in
                                    let isSelected = selectedType == type
                                    Button {
                                        Haptics.selection()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedType = type
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 14))
                                                .foregroundStyle(isSelected ? t.ink : t.muted)
                                            Text(type.displayName)
                                                .font(.system(size: 9, weight: isSelected ? .medium : .regular))
                                                .foregroundStyle(isSelected ? t.ink : t.muted)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
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

                            Text(selectedType.detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(t.faint)
                                .lineSpacing(2)

                            // Times-per-week cadence for habit/recurring goals.
                            if selectedType.isHabitual {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        SectionLabel(title: "Times per week")
                                        Text(cadenceCaption)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(t.faint)
                                    }
                                    Spacer()
                                    Stepper(
                                        value: $timesPerWeek.animation(.easeInOut(duration: 0.15)),
                                        in: 1...7
                                    ) {
                                        Text("\(timesPerWeek)")
                                            .font(.system(size: 17, design: .monospaced))
                                            .monospacedDigit()
                                            .foregroundStyle(t.ink)
                                    }
                                    .labelsHidden()
                                    .fixedSize()
                                    .onChange(of: timesPerWeek) { _, _ in Haptics.selection() }
                                }
                            }
                        }

                        // Measurable target (optional, collapsible)
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $metricEnabled.animation(.easeInOut(duration: 0.2))) {
                                VStack(alignment: .leading, spacing: 2) {
                                    SectionLabel(title: "Measurable target")
                                    Text("Watch a number move toward a goal")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(t.faint)
                                }
                            }
                            .tint(t.accent)
                            .onChange(of: metricEnabled) { _, _ in Haptics.selection() }

                            if metricEnabled {
                                // Baseline + target
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SectionLabel(title: "Baseline")
                                        TextField("0", text: $baselineText)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 16, design: .monospaced))
                                            .monospacedDigit()
                                            .foregroundStyle(t.ink)
                                        t.rule.frame(height: 1)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        SectionLabel(title: "Target")
                                        TextField("0", text: $targetText)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 16, design: .monospaced))
                                            .monospacedDigit()
                                            .foregroundStyle(t.ink)
                                        t.rule.frame(height: 1)
                                    }
                                }

                                // Unit
                                VStack(alignment: .leading, spacing: 6) {
                                    SectionLabel(title: "Unit (optional)")
                                    TextField("e.g. lbs · pages · $", text: $unitText)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundStyle(t.ink2)
                                    t.rule.frame(height: 1)
                                }

                                // Direction picker (mirrors the horizon dot-button row)
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel(title: "Direction")
                                    HStack(spacing: 8) {
                                        ForEach(MetricDirection.allCases) { direction in
                                            let isSelected = selectedDirection == direction
                                            Button {
                                                Haptics.selection()
                                                selectedDirection = direction
                                            } label: {
                                                VStack(spacing: 4) {
                                                    Image(systemName: direction.icon)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(isSelected ? t.ink : t.muted)
                                                    Text(direction.displayName)
                                                        .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                                                        .foregroundStyle(isSelected ? t.ink : t.muted)
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

    private var cadenceCaption: String {
        if timesPerWeek >= 7 { return "every day" }
        if timesPerWeek == 1 { return "once a week" }
        return "\(timesPerWeek)× a week"
    }

    private func recurrence(for type: GoalType) -> GoalRecurrence {
        switch type {
        case .habit: return .daily
        case .recurring: return timesPerWeek >= 7 ? .daily : .weekly
        case .project, .milestone, .accumulation: return .none
        }
    }

    private func addGoal() {
        guard let profile else { return }
        Haptics.success()
        let priority = (profile.goals?.count ?? 0) + 1
        let goal = Goal(title: title, domain: selectedDomain, priority: priority)
        goal.subtitle = subtitle
        // Cap details length to match every other write path (GoalDetailView /
        // GoalQuickSheet / GoalImportService all clamp to 500 chars).
        goal.details = String(details.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        goal.horizon = selectedHorizon
        goal.goalType = selectedType
        goal.timesPerWeek = selectedType.isHabitual ? timesPerWeek : 0
        goal.recurrence = recurrence(for: selectedType)
        goal.streak = Streak()

        if metricEnabled {
            let baseline = Double(baselineText.trimmingCharacters(in: .whitespaces)) ?? 0
            let target = Double(targetText.trimmingCharacters(in: .whitespaces)) ?? 0
            goal.metricEnabled = true
            goal.baselineValue = baseline
            goal.targetValue = target
            goal.currentValue = baseline
            goal.unit = unitText.trimmingCharacters(in: .whitespaces)
            goal.direction = selectedDirection
        }
        modelContext.insert(goal)
        goal.profile = profile
        try? modelContext.save()

        let questions = DomainAssessmentQuestions.questions(for: selectedDomain)
        if !questions.isEmpty {
            newGoal = goal
        } else {
            dismiss()
        }
    }
}
