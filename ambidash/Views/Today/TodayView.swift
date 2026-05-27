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

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased() + " · " + Date.now.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(t.muted)

                            Text("Today, as you set it.")
                                .font(.system(size: 28, weight: .regular, design: .serif))
                                .tracking(-0.3)
                                .foregroundStyle(t.ink)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 14)

                        if let plan = todayPlan {
                            todayContent(plan, t: t)
                        } else {
                            emptyState(t)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Plan Content

    @ViewBuilder
    private func todayContent(_ plan: DailyPlan, t: ResolvedTheme) -> some View {
        let sorted = plan.actions.sorted { $0.timeSlot < $1.timeSlot }
        let currentAction = sorted.first { $0.statusRaw == "pending" }

        VStack(alignment: .leading, spacing: 22) {
            // "Now" strip
            if let current = currentAction {
                nowStrip(current, t: t)
                    .padding(.horizontal, 22)
            }

            // The whole day
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "The whole day")
                    .padding(.horizontal, 22)

                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, action in
                        let isLast = index == sorted.count - 1
                        timelineRow(action, isNow: action.id == currentAction?.id, t: t, showDivider: !isLast)
                    }
                }
                .padding(.horizontal, 22)
            }

            // Time accounting
            timeAccounting(plan, t: t)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Now Strip

    @ViewBuilder
    private func nowStrip(_ action: PlannedAction, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOW · \(action.durationMinutes)M")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(t.accent)

            Text(action.title)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)

            if !action.whyReasoning.isEmpty {
                Text(action.whyReasoning)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .padding(.top, 2)
            }

            HStack(spacing: 8) {
                PillButton(label: "Mark done", primary: true) {
                    action.statusRaw = "done"
                    action.completedAt = .now
                    handleDone(action)
                }
                PillButton(label: "Skip") {
                    action.statusRaw = "skipped"
                    try? modelContext.save()
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(t.hair, lineWidth: 0.5)
        )
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(_ action: PlannedAction, isNow: Bool, t: ResolvedTheme, showDivider: Bool) -> some View {
        let isDone = action.statusRaw == "done"
        let isSkipped = action.statusRaw == "skipped"
        let isPast = isDone || isSkipped

        HStack(alignment: .top, spacing: 12) {
            // Time
            Text(action.timeSlot.isEmpty ? "—" : action.timeSlot)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isPast ? t.faint : t.muted)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 4)

            // Dot
            ZStack {
                Circle()
                    .fill(isNow ? t.accent : (isPast ? t.faint : .clear))
                    .frame(width: 9, height: 9)
                if !isNow && !isPast {
                    Circle()
                        .stroke(t.ink2, lineWidth: 1)
                        .frame(width: 9, height: 9)
                }
                if isNow {
                    Circle()
                        .stroke(t.accent.opacity(0.5), lineWidth: 0.5)
                        .frame(width: 15, height: 15)
                }
            }
            .padding(.top, 5)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .strikethrough(isPast, color: t.faint)
                    .foregroundStyle(isPast ? t.muted : t.ink)

                if !action.whyReasoning.isEmpty {
                    Text(action.whyReasoning)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
            .opacity(isPast ? 0.5 : 1)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if showDivider {
                t.hair.frame(height: 0.5)
            }
        }
    }

    // MARK: - Time Accounting

    @ViewBuilder
    private func timeAccounting(_ plan: DailyPlan, t: ResolvedTheme) -> some View {
        let done = plan.actions.filter { $0.statusRaw == "done" }
        let totalDoneMinutes = done.reduce(0) { $0 + $1.durationMinutes }
        let totalPlannedMinutes = plan.actions.reduce(0) { $0 + $1.durationMinutes }
        let unaccounted = max(0, 480 - totalPlannedMinutes)

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Time honestly accounted for")

            // Stacked bar
            GeometryReader { geo in
                let total = CGFloat(totalPlannedMinutes + unaccounted)
                HStack(spacing: 0) {
                    t.ink
                        .frame(width: geo.size.width * CGFloat(totalDoneMinutes) / total)
                    t.accent
                        .frame(width: geo.size.width * CGFloat(totalPlannedMinutes - totalDoneMinutes) / total)
                    t.hair
                        .frame(width: geo.size.width * CGFloat(unaccounted) / total)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 10)

            // Legend
            HStack(spacing: 14) {
                legendDot(color: t.ink, label: "Done · \(totalDoneMinutes)m", t: t)
                legendDot(color: t.accent, label: "Planned · \(totalPlannedMinutes - totalDoneMinutes)m", t: t)
                legendDot(color: t.hair, label: "Free · \(unaccounted)m", t: t)
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    private func legendDot(color: Color, label: String, t: ResolvedTheme) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.ink2)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 80)

            // Circle mark
            ZStack {
                Circle().stroke(t.hair, lineWidth: 0.5).frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(t.accent, lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                    .rotationEffect(Angle.degrees(-90))
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(t.ink)
            }

            VStack(spacing: 8) {
                Text("No plan for today.")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink)

                Text("Generate one from your goals — it takes a few seconds.")
                    .font(.system(size: 13))
                    .foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(label: isGenerating
                ? (AIConfig.isConfigured ? "AI is thinking…" : "Generating…")
                : "Generate today's plan"
            ) {
                generatePlan()
            }
            .padding(.horizontal, 40)
            .disabled(isGenerating)

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Logic (unchanged)

    private func generatePlan() {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            guard PremiumGateService.canGeneratePlan() else { return }

            let goals = profile?.goals ?? []
            let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6
            let planFormat: PlanFormat = {
                if let raw = profile?.workStylePreference?.planFormat, let fmt = PlanFormat(rawValue: raw) { return fmt }
                return .focusBlocks
            }()

            if AIConfig.isConfigured {
                if let aiPlan = await generateAIPlan(goals: goals, maxActions: maxActions, format: planFormat) {
                    modelContext.insert(aiPlan)
                    try? modelContext.save()
                    PremiumGateService.recordPlanGeneration()
                    return
                }
            }

            let templates = PlanGenerator.generateActions(for: goals, freeMinutes: 480, maxActions: maxActions)
            let plan = DailyPlan(date: .now, format: planFormat)
            plan.actionCount = templates.count
            let timeSlots = ["07:00", "08:30", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"]
            for (i, tmpl) in templates.enumerated() {
                let action = PlannedAction(title: tmpl.title, why: tmpl.why, timeSlot: i < timeSlots.count ? timeSlots[i] : "", duration: tmpl.durationMinutes)
                plan.actions.append(action)
            }
            modelContext.insert(plan)
            try? modelContext.save()
            PremiumGateService.recordPlanGeneration()
        }
    }

    private func generateAIPlan(goals: [Goal], maxActions: Int, format: PlanFormat) async -> DailyPlan? {
        do {
            let snapshot = try? modelContext.fetch(FetchDescriptor<IntegrationSnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first
            let jsonText = try await AIService.generatePlanJSON(goals: goals, snapshot: snapshot, profile: profile)
            guard let data = jsonText.data(using: .utf8),
                  let actions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            let plan = DailyPlan(date: .now, format: format)
            for dict in actions.prefix(maxActions) {
                let action = PlannedAction(
                    title: dict["title"] as? String ?? "",
                    why: dict["why"] as? String ?? "",
                    timeSlot: dict["time_slot"] as? String ?? "",
                    duration: dict["duration_minutes"] as? Int ?? 30
                )
                plan.actions.append(action)
            }
            plan.actionCount = plan.actions.count
            return plan
        } catch { return nil }
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
