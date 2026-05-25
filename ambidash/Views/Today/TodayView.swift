import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDateInToday($0.date) }
    }

    private var planFormat: PlanFormat {
        if let raw = profile?.workStylePreference?.planFormat,
           let fmt = PlanFormat(rawValue: raw) {
            return fmt
        }
        return .focusBlocks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let plan = todayPlan {
                        planContent(plan)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: DailyPlan) -> some View {
        let sorted = plan.actions.sorted {
            if $0.statusRaw == "pending" && $1.statusRaw != "pending" { return true }
            if $0.statusRaw != "pending" && $1.statusRaw == "pending" { return false }
            return $0.timeSlot < $1.timeSlot
        }

        VStack(alignment: .leading, spacing: 16) {
            planHeader(plan)

            switch planFormat {
            case .focusBlocks:
                FocusBlocksView(
                    actions: sorted,
                    onDone: { markDone($0, plan: plan) },
                    onSkip: { markSkipped($0, plan: plan) }
                )
            case .singleAction:
                SingleActionView(
                    actions: sorted,
                    onDone: { markDone($0, plan: plan) },
                    onSkip: { markSkipped($0, plan: plan) }
                )
            case .priorityList:
                PriorityListView(
                    actions: sorted,
                    onDone: { markDone($0, plan: plan) },
                    onSkip: { markSkipped($0, plan: plan) }
                )
            }
        }
    }

    @ViewBuilder
    private func planHeader(_ plan: DailyPlan) -> some View {
        let doneCount = plan.actions.filter { $0.statusRaw == "done" }.count
        let total = plan.actions.count
        let progress = total > 0 ? Double(doneCount) / Double(total) : 0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(planFormat.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(doneCount)/\(total) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(.green)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("No plan for today")
                    .font(.title3.weight(.semibold))

                Text("Generate a personalized action plan based on your goals.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: generatePlan) {
                Text("Generate Today's Plan")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func generatePlan() {
        let goals = profile?.goals ?? []
        let freeMinutes = 480
        let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6

        let templates = PlanGenerator.generateActions(for: goals, freeMinutes: freeMinutes, maxActions: maxActions)

        let plan = DailyPlan(date: .now, format: planFormat)
        plan.actionCount = templates.count

        let timeSlots = ["07:00", "08:30", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"]

        for (index, template) in templates.enumerated() {
            let action = PlannedAction(
                title: template.title,
                why: template.why,
                timeSlot: index < timeSlots.count ? timeSlots[index] : "",
                duration: template.durationMinutes
            )
            plan.actions.append(action)
        }

        modelContext.insert(plan)
        try? modelContext.save()
    }

    private func markDone(_ action: PlannedAction, plan: DailyPlan) {
        action.statusRaw = "done"
        action.completedAt = .now
        handleDone(action)
    }

    private func markSkipped(_ action: PlannedAction, plan: DailyPlan) {
        action.statusRaw = "skipped"
        try? modelContext.save()
    }

    private func handleDone(_ action: PlannedAction) {
        let goals = profile?.goals ?? []
        for goal in goals {
            let temps = PlanGenerator.templates(for: goal.domain)
            if temps.contains(where: { $0.0 == action.title }) {
                goal.lastProgressDate = .now
                goal.streak?.recordActivity()
                break
            }
        }
        try? modelContext.save()
    }
}
