import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDateInToday($0.date) }
    }

    @State private var isGenerating = false

    private var planFormat: PlanFormat {
        if let raw = profile?.workStylePreference?.planFormat,
           let fmt = PlanFormat(rawValue: raw) {
            return fmt
        }
        return .focusBlocks
    }

    var body: some View {
        let t = tm.resolved
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
            .background(t.bg)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: DailyPlan) -> some View {
        let t = tm.resolved
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
        let t = tm.resolved
        let doneCount = plan.actions.filter { $0.statusRaw == "done" }.count
        let total = plan.actions.count
        let progress = total > 0 ? Double(doneCount) / Double(total) : 0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(planFormat.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(t.muted)
                Spacer()
                Text("\(doneCount)/\(total) completed")
                    .font(.caption)
                    .foregroundStyle(t.muted)
            }

            ProgressView(value: progress)
                .tint(t.accent)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let t = tm.resolved
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(t.accent)

            VStack(spacing: 8) {
                Text("No plan for today")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(t.ink)

                Text("Generate a personalized action plan based on your goals.")
                    .font(.body)
                    .foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
            }

            AccentButton(label: isGenerating
                ? (AIConfig.isConfigured ? "AI is thinking..." : "Generating...")
                : (PremiumGateService.remainingPlans > 0
                    ? (AIConfig.isConfigured ? "Generate AI Plan" : "Generate Plan")
                    : "Upgrade for more plans"),
                action: generatePlan
            )
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }

    private func generatePlan() {
        guard !isGenerating else { return }
        isGenerating = true

        Task {
            defer { isGenerating = false }
            guard PremiumGateService.canGeneratePlan() else { return }

            let goals = profile?.goals ?? []
            let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6

            // Try AI-powered generation first
            if AIConfig.isConfigured {
                if let aiPlan = await generateAIPlan(goals: goals, maxActions: maxActions) {
                    modelContext.insert(aiPlan)
                    try? modelContext.save()
                    PremiumGateService.recordPlanGeneration()
                    return
                }
            }

            // Fallback to template-based
            let freeMinutes = 480
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
            PremiumGateService.recordPlanGeneration()
        }
    }

    private func generateAIPlan(goals: [Goal], maxActions: Int) async -> DailyPlan? {
        do {
            let snapshot = try? modelContext.fetch(FetchDescriptor<IntegrationSnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first
            let jsonText = try await AIService.generatePlanJSON(goals: goals, snapshot: snapshot, profile: profile)

            guard let data = jsonText.data(using: .utf8),
                  let actions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }

            let plan = DailyPlan(date: .now, format: planFormat)
            for actionDict in actions.prefix(maxActions) {
                let title = actionDict["title"] as? String ?? ""
                let why = actionDict["why"] as? String ?? ""
                let duration = actionDict["duration_minutes"] as? Int ?? 30
                let timeSlot = actionDict["time_slot"] as? String ?? ""
                let action = PlannedAction(title: title, why: why, timeSlot: timeSlot, duration: duration)
                plan.actions.append(action)
            }
            plan.actionCount = plan.actions.count
            return plan
        } catch {
            return nil
        }
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
