import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]

    /// #8 — the goal the user said they're postponing today, captured in
    /// MorningBriefView and shared via UserDefaults so it can be folded into plan
    /// generation as explicit intent. Read-only here.
    @AppStorage("morningBrief.postponingIntent") private var postponingIntent: String = ""

    private var latestSnapshot: IntegrationSnapshot? { snapshots.first }
    private var latestReflection: Reflection? { reflections.first }

    private var profile: UserProfile? { profiles.first }
    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDateInToday($0.date) }
    }

    /// The most recent plan strictly before today — the source CarryOverService
    /// pulls unfinished work forward from. nil when there is no prior plan.
    private var mostRecentPriorPlan: DailyPlan? {
        plans.first { $0.date < Calendar.current.startOfDay(for: .now) }
    }

    @State private var isGenerating = false
    @State private var showAddAction = false
    @State private var rescheduleTarget: PlannedAction?
    /// #14 — the action awaiting a skip reason. Presents SkipReasonSheet.
    @State private var skipTarget: PlannedAction?

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
                                .font(t.heading(28))
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
            .toolbar {
                if let plan = todayPlan {
                    ToolbarItem(placement: .topBarTrailing) {
                        planMenu(plan, t: t)
                    }
                }
            }
            .sheet(isPresented: $showAddAction) {
                if let plan = todayPlan {
                    AddActionSheet(plan: plan, goals: (profile?.goals ?? nil) ?? [])
                }
            }
            .sheet(item: $rescheduleTarget) { action in
                RescheduleSheet(action: action)
            }
            .sheet(item: $skipTarget) { action in
                SkipReasonSheet(action: action)
            }
        }
    }

    // MARK: - Plan Menu (reachable controls once a plan exists)

    @ViewBuilder
    private func planMenu(_ plan: DailyPlan, t: ResolvedTheme) -> some View {
        Menu {
            Button {
                showAddAction = true
            } label: {
                Label("Add action", systemImage: "plus")
            }

            Button {
                replanRestOfToday(plan)
            } label: {
                Label("Re-plan rest of today", systemImage: "clock.arrow.circlepath")
            }
            .disabled(isGenerating)

            Divider()

            Button(role: .destructive) {
                regeneratePlan(plan)
            } label: {
                Label("Regenerate plan", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isGenerating)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(t.ink)
        }
    }

    // MARK: - Plan Content

    @ViewBuilder
    private func todayContent(_ plan: DailyPlan, t: ResolvedTheme) -> some View {
        let sorted = (plan.actions ?? []).sorted { $0.timeSlot < $1.timeSlot }
        let currentAction = sorted.first { $0.statusRaw == "pending" }

        let allDone = sorted.allSatisfy { $0.statusRaw != "pending" }

        VStack(alignment: .leading, spacing: t.space.section) {
            // Completion state
            if allDone && !sorted.isEmpty {
                completionCard(plan: plan, t: t)
                    .padding(.horizontal, 22)
            }

            // "Now" strip
            if let current = currentAction {
                nowStrip(current, t: t)
                    .padding(.horizontal, 22)
                    .fadeSlideIn(delay: 0)
            }

            // The whole day
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(title: "The whole day")
                    Spacer()
                    PillButton(label: "Add action") {
                        Haptics.light()
                        showAddAction = true
                    }
                }
                .padding(.horizontal, 22)

                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, action in
                        let isLast = index == sorted.count - 1
                        timelineRow(action, isNow: action.id == currentAction?.id, t: t, showDivider: !isLast)
                            .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, 22)
            }

            // Time accounting
            timeAccounting(plan, t: t)
                .padding(.horizontal, 22)
                .fadeSlideIn(delay: 0.1)
        }
    }

    // MARK: - Now Strip

    @ViewBuilder
    private func nowStrip(_ action: PlannedAction, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("NOW · \(action.durationMinutes)M")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(t.accent)

                if action.carriedOverFrom != nil {
                    carriedOverTag(t)
                }
            }

            Text(action.title)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)

            cueTargetLine(action, t: t)
                .padding(.top, 2)

            if !action.whyReasoning.isEmpty {
                Text(action.whyReasoning)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .padding(.top, 2)
            }

            HStack(spacing: 8) {
                PillButton(label: "Mark done", primary: true) {
                    Haptics.success()
                    action.statusRaw = "done"
                    action.completedAt = .now
                    handleDone(action)
                }
                PillButton(label: "Skip") {
                    Haptics.light()
                    skipTarget = action
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
        .contextMenu {
            actionContextMenu(action)
        }
    }

    // MARK: - Completion Card

    @ViewBuilder
    private func completionCard(plan: DailyPlan, t: ResolvedTheme) -> some View {
        let doneCount = (plan.actions ?? []).filter { $0.statusRaw == "done" }.count
        let skippedCount = (plan.actions ?? []).filter { $0.statusRaw == "skipped" }.count

        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(t.ok)

            Text("Day complete.")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)

            Text("\(doneCount) done · \(skippedCount) skipped")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(t.muted)

            if skippedCount == 0 {
                Text("You finished everything you planned. Notice that.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(t.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .onAppear { Haptics.success() }
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(_ action: PlannedAction, isNow: Bool, t: ResolvedTheme, showDivider: Bool) -> some View {
        let isDone = action.statusRaw == "done"
        let isSkipped = action.statusRaw == "skipped"
        let isPast = isDone || isSkipped
        // PLAN REWRITE — fixed anchors + routines are the day's structure: render
        // them muted and lighter than goal-work, which gets the normal emphasis.
        let kind = action.anchorKind
        let isStructure = kind == .fixed || kind == .routine
        // Prefer the instruction-style relative cue ("Before 13:00") over the raw
        // clock when the planner set one.
        let whenLabel: String = {
            if !action.scheduleCue.isEmpty { return action.scheduleCue }
            return action.timeSlot.isEmpty ? "—" : action.timeSlot
        }()

        HStack(alignment: .top, spacing: 12) {
            // Time / relative cue
            Text(whenLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isPast ? t.faint : (isStructure ? t.faint : t.muted))
                .frame(width: 44, alignment: .leading)
                .lineLimit(2)
                .padding(.top, 4)

            // Dot
            ZStack {
                Circle()
                    .fill(isNow ? t.accent : (isPast ? t.faint : .clear))
                    .frame(width: 9, height: 9)
                if !isNow && !isPast {
                    Circle()
                        .stroke(isStructure ? t.hair : t.ink2, lineWidth: 1)
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
                HStack(spacing: 6) {
                    Text(action.title)
                        .font(.system(size: isStructure ? 14 : 15, weight: .regular, design: .serif))
                        .strikethrough(isPast, color: t.faint)
                        .foregroundStyle(isPast ? t.muted : (isStructure ? t.ink2 : t.ink))

                    if isStructure {
                        anchorTag(kind, t: t)
                    }

                    if action.carriedOverFrom != nil && !isPast {
                        carriedOverTag(t)
                    }
                }

                if !isPast {
                    cueTargetLine(action, t: t)
                }

                if !action.whyReasoning.isEmpty && !isStructure {
                    Text(action.whyReasoning)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
            .opacity(isPast ? 0.5 : (isStructure ? 0.85 : 1))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if showDivider {
                t.hair.frame(height: 0.5)
            }
        }
        .contextMenu {
            actionContextMenu(action)
        }
    }

    /// #10 — surfaces the if-then cue ("when X") and the quantitative target
    /// ("20 reps") as a compact tag row beneath the action title. Renders nothing
    /// when the action carries neither (e.g. older actions, manual additions).
    @ViewBuilder
    private func cueTargetLine(_ action: PlannedAction, t: ResolvedTheme) -> some View {
        let hasCue = !action.cueTrigger.isEmpty
        let hasTarget = action.targetAmount != nil && !action.targetUnit.isEmpty
        if hasCue || hasTarget {
            HStack(spacing: 6) {
                if hasCue {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8, weight: .medium))
                        Text(action.cueTrigger.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .lineLimit(1)
                    }
                    .foregroundStyle(t.accent)
                }
                if hasTarget, let amount = action.targetAmount {
                    Text("\(formatTarget(amount)) \(action.targetUnit.uppercased())")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(t.ink2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(t.hair)
                        .clipShape(Capsule())
                }
            }
        }
    }

    /// Formats a target amount as an int when whole, else one decimal place.
    private func formatTarget(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// PLAN REWRITE — a small tag marking a fixed anchor or daily routine so the
    /// day's structure reads distinctly from goal-work.
    @ViewBuilder
    private func anchorTag(_ kind: PlannedAction.AnchorKind, t: ResolvedTheme) -> some View {
        let label = kind == .routine ? "ROUTINE" : "ANCHOR"
        Text(label)
            .font(.system(size: 7, weight: .medium, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(t.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(t.hair)
            .clipShape(Capsule())
    }

    /// A small "carried over" tag, marking actions resurfaced from a prior day.
    @ViewBuilder
    private func carriedOverTag(_ t: ResolvedTheme) -> some View {
        Text("CARRIED OVER")
            .font(.system(size: 7, weight: .medium, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(t.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(t.hair)
            .clipShape(Capsule())
    }

    /// Shared per-row context menu: done/skip plus the C2 reschedule + move-to-
    /// tomorrow controls. Only offered while the action is still pending.
    @ViewBuilder
    private func actionContextMenu(_ action: PlannedAction) -> some View {
        if action.statusRaw == "pending" {
            Button {
                action.statusRaw = "done"
                action.completedAt = .now
                handleDone(action)
                Haptics.success()
            } label: {
                Label("Mark done", systemImage: "checkmark")
            }
            Button {
                Haptics.light()
                skipTarget = action
            } label: {
                Label("Skip", systemImage: "forward")
            }

            Divider()

            Button {
                Haptics.light()
                rescheduleTarget = action
            } label: {
                Label("Reschedule", systemImage: "clock")
            }
            Button {
                moveToTomorrow(action)
            } label: {
                Label("Move to tomorrow", systemImage: "arrow.right.to.line")
            }
        }
    }

    // MARK: - Time Accounting

    @ViewBuilder
    private func timeAccounting(_ plan: DailyPlan, t: ResolvedTheme) -> some View {
        // PLAN REWRITE — account for the EFFORT the user puts in (goal-work +
        // routines), not the fixed anchors (work block, sleep, meals) that fill the
        // day regardless. Otherwise an 8h work-block anchor swamps the bar.
        let effort = (plan.actions ?? []).filter { $0.anchorKind != .fixed }
        let done = effort.filter { $0.statusRaw == "done" }
        let totalDoneMinutes = done.reduce(0) { $0 + $1.durationMinutes }
        let totalPlannedMinutes = effort.reduce(0) { $0 + $1.durationMinutes }
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
            .scaleOnPress()

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 22)
        .fadeSlideIn(delay: 0)
    }

    // MARK: - Generation

    private var resolvedPlanFormat: PlanFormat {
        if let raw = profile?.workStylePreference?.planFormat, let fmt = PlanFormat(rawValue: raw) { return fmt }
        return .focusBlocks
    }

    /// Full plan generation from the empty state. Carries forward yesterday's
    /// unfinished work and links every generated action to its goal's current
    /// WEEK Milestone so completing it rolls up the C1 chain.
    private func generatePlan() {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            guard PremiumGateService.canGeneratePlan() else { return }

            let goals = (profile?.goals ?? nil) ?? []
            let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6
            let planFormat = resolvedPlanFormat

            // Capture the carry-over source BEFORE inserting today's plan so we
            // don't try to carry into a plan that doesn't exist yet, and so the
            // freshly inserted plan isn't itself a candidate "prior" plan.
            let prior = mostRecentPriorPlan

            let plan = DailyPlan(date: .now, format: planFormat)
            modelContext.insert(plan)
            await populate(plan, goals: goals, maxActions: maxActions)

            if let prior {
                CarryOverService.carryForward(into: plan, from: prior, context: modelContext)
            }
            try? modelContext.save()
            PremiumGateService.recordPlanGeneration()
            Haptics.medium()
        }
    }

    /// #10 — the real calendar free-minute budget for today, sourced from the
    /// latest IntegrationSnapshot. nil when no snapshot exists (or it reports a
    /// non-positive budget), in which case SlotScheduler / PlanGenerator fall back
    /// to their fixed defaults.
    private var resolvedFreeMinutes: Int? {
        guard let minutes = latestSnapshot?.calendarFreeMinutes, minutes > 0 else { return nil }
        return minutes
    }

    /// #8 — assembles the adaptive plan context: the most recent settled actions
    /// (done + skipped, with captured skip reasons), the latest reflection, and
    /// the user's postpone/focus intent from the morning brief.
    private func buildPlanContext() -> AIService.PlanContext {
        // Pull settled actions from the most recent prior plan (yesterday's), so
        // the AI sees what actually happened most recently rather than ancient
        // history. Falls back to empty when there's no prior plan.
        let recent = mostRecentPriorPlan?.actions ?? []
        let done = recent.filter { $0.statusRaw == "done" }
        let skipped = recent.filter { $0.statusRaw == "skipped" }
        let intent = postponingIntent.trimmingCharacters(in: .whitespaces)
        return AIService.PlanContext(
            recentDone: done,
            recentSkipped: skipped,
            latestReflection: latestReflection,
            postponingIntent: intent.isEmpty ? nil : intent,
            // FOUNDATION — daily-rhythm preferences so the planner builds the day
            // around the user's real anchors (wake/sleep, meals, work, routines).
            userPreferences: profile?.userPreferences
        )
    }

    /// Appends a freshly generated batch of actions (AI first, template fallback)
    /// into `plan`, sized to `maxActions`. Each action is inserted into the
    /// context and linked to its goal's current WEEK Milestone.
    private func populate(_ plan: DailyPlan, goals: [Goal], maxActions: Int) async {
        let actions: [PlannedAction]
        if AIConfig.isConfigured, let aiActions = await buildAIActions(goals: goals, maxActions: maxActions) {
            actions = aiActions
        } else {
            actions = buildTemplateActions(goals: goals, maxActions: maxActions)
        }
        for action in actions {
            modelContext.insert(action)
            action.plan = plan
        }
        plan.actionCount = (plan.actions ?? []).count
    }

    /// Builds the offline plan as a single woven timeline — fixed anchors + daily
    /// routines (from the user's preferences) interleaved with goal-work slotted
    /// into the free gaps. Goal-work actions link to their goal's current week
    /// Milestone via `ensureWeekMilestone`. Actions are NOT yet inserted — the
    /// caller inserts + attaches them to a plan.
    private func buildTemplateActions(goals: [Goal], maxActions: Int) -> [PlannedAction] {
        // PLAN REWRITE — weave anchors + routines + goal-work via PlanGenerator,
        // grounded in the user's daily-rhythm preferences (nil → goal-work only).
        let freeMinutes = resolvedFreeMinutes
        // LEARNING ENGINE — fold the user's recent logged actuals + energy check-ins
        // into a LearnedProfile so the offline timeline uses their real durations and
        // active hours. Empty (no logs yet) ⇒ identical to the prior behaviour.
        let learned = LearningService.buildProfile(from: modelContext)
        let timeline = PlanGenerator.generateTimeline(
            for: goals,
            prefs: profile?.userPreferences,
            freeMinutes: freeMinutes,
            maxGoalActions: maxActions,
            learned: learned
        )
        return timeline.map { entry in
            let resolvedGoal = entry.goalID.flatMap { gid in goals.first { $0.id == gid } }
            return PlannedAction(
                title: entry.title,
                why: entry.why,
                timeSlot: entry.timeSlot,
                duration: entry.durationMinutes,
                goalID: entry.goalID,
                goalTitleSnapshot: entry.goalTitle,
                milestone: resolvedGoal.map { WeeklyPlanService.ensureWeekMilestone(for: $0, context: modelContext) },
                cueTrigger: entry.cueTrigger,
                targetAmount: entry.targetAmount,
                targetUnit: entry.targetUnit,
                anchorType: entry.anchorType.rawValue,
                scheduleCue: entry.scheduleCue
            )
        }
    }

    /// Calls the AI planner and parses its JSON into actions, each linked to its
    /// goal's current week Milestone. Returns nil on any failure so the caller can
    /// fall back to templates. Actions are NOT yet inserted.
    private func buildAIActions(goals: [Goal], maxActions: Int) async -> [PlannedAction]? {
        do {
            let snapshot = latestSnapshot
            // #8 — fold recent done/skipped history + latest reflection + the
            // morning-brief postpone intent into the planner context.
            let planContext = buildPlanContext()
            let jsonText = try await AIService.generatePlanJSON(goals: goals, snapshot: snapshot, profile: profile, planContext: planContext)
            guard let data = jsonText.data(using: .utf8),
                  let actions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            let goalIDs = Set(goals.map { $0.id })
            var built: [PlannedAction] = []
            // PLAN REWRITE — `maxActions` caps GOAL-WORK, not the whole day: fixed
            // anchors + daily routines structure the day and are always kept, while
            // goal-work is limited to the user's preferred count so the timeline
            // stays focused. Count goal-work as we go.
            var goalWorkCount = 0
            for dict in actions {
                let kindRaw = dict["anchor_type"] as? String ?? "goal_work"
                let isGoalWork = (PlannedAction.AnchorKind(rawValue: kindRaw) ?? .goalWork) == .goalWork
                if isGoalWork {
                    if goalWorkCount >= maxActions { continue }
                    goalWorkCount += 1
                }
                var resolvedGoalID: UUID? = nil
                if let goalIDStr = dict["goal_id"] as? String,
                   let parsed = UUID(uuidString: goalIDStr),
                   goalIDs.contains(parsed) {
                    resolvedGoalID = parsed
                }
                let resolvedGoal = resolvedGoalID.flatMap { gid in
                    goals.first { $0.id == gid }
                }
                // Capture the measurable increment only when the goal has a
                // target; the model is instructed to omit "amount" otherwise.
                var loggedAmount: Double? = nil
                if let goal = resolvedGoal, goal.hasTarget {
                    if let amount = dict["amount"] as? Double {
                        loggedAmount = amount
                    } else if let amount = dict["amount"] as? Int {
                        loggedAmount = Double(amount)
                    }
                }
                // #10 — parse the quantitative target (display-facing) and the
                // if-then cue. target_amount may arrive as Double or Int.
                var targetAmount: Double? = nil
                if let v = dict["target_amount"] as? Double {
                    targetAmount = v
                } else if let v = dict["target_amount"] as? Int {
                    targetAmount = Double(v)
                }
                let targetUnit = dict["target_unit"] as? String ?? ""
                let cueTrigger = dict["cue_trigger"] as? String ?? ""
                // PLAN REWRITE — the anchor kind (fixed | routine | goal_work) and
                // the instruction-style relative cue ("Before 13:00", "After class").
                // Fixed/routine entries have no goal, so don't force-link a milestone.
                let anchorTypeRaw = dict["anchor_type"] as? String ?? "goal_work"
                let anchorKind = PlannedAction.AnchorKind(rawValue: anchorTypeRaw) ?? .goalWork
                let scheduleCue = dict["schedule_cue"] as? String ?? ""
                // C2 — ensure (get-or-create) the goal's current WEEK milestone
                // BEFORE constructing the action, so its id is available to link.
                // Only goal-work entries roll up into a milestone.
                let weekMilestone = (anchorKind == .goalWork)
                    ? resolvedGoal.map { WeeklyPlanService.ensureWeekMilestone(for: $0, context: modelContext) }
                    : nil
                built.append(PlannedAction(
                    title: dict["title"] as? String ?? "",
                    why: dict["why"] as? String ?? "",
                    timeSlot: dict["time_slot"] as? String ?? "",
                    duration: dict["duration_minutes"] as? Int ?? 30,
                    goalID: anchorKind == .goalWork ? resolvedGoalID : nil,
                    goalTitleSnapshot: anchorKind == .goalWork ? resolvedGoal?.title : nil,
                    loggedAmount: anchorKind == .goalWork ? loggedAmount : nil,
                    milestone: weekMilestone,
                    cueTrigger: cueTrigger,
                    targetAmount: targetAmount,
                    targetUnit: targetUnit,
                    anchorType: anchorKind.rawValue,
                    scheduleCue: scheduleCue
                ))
            }
            // #10 — if the AI left time slots blank, assign them from the real
            // free-minute budget via SlotScheduler (fixed slots when unavailable).
            if built.contains(where: { $0.timeSlot.isEmpty }) {
                let durations = built.map { $0.durationMinutes }
                let slots = SlotScheduler.assignSlots(count: built.count, durations: durations, freeMinutes: resolvedFreeMinutes)
                for (i, action) in built.enumerated() where action.timeSlot.isEmpty {
                    action.timeSlot = i < slots.count ? slots[i] : ""
                }
            }
            return built
        } catch { return nil }
    }

    // MARK: - Re-planning controls (once a plan exists)

    /// Clears today's plan and re-runs full generation, marking the resulting
    /// plan as user-initiated (`regenerated = true`). Carries forward yesterday's
    /// unfinished work just like the initial generation.
    private func regeneratePlan(_ plan: DailyPlan) {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            guard PremiumGateService.canGeneratePlan() else { return }

            let goals = (profile?.goals ?? nil) ?? []
            let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6
            let prior = mostRecentPriorPlan

            // Clear the existing actions (cascade delete) before rebuilding.
            for action in (plan.actions ?? []) {
                modelContext.delete(action)
            }
            plan.actions = []

            await populate(plan, goals: goals, maxActions: maxActions)

            if let prior {
                CarryOverService.carryForward(into: plan, from: prior, context: modelContext)
            }

            plan.regenerated = true
            plan.generatedAt = .now
            try? modelContext.save()
            PremiumGateService.recordPlanGeneration()
            Haptics.medium()
        }
    }

    /// Re-plans only the still-pending actions: drops them and regenerates a
    /// fresh set for the remainder of today, preserving everything already done
    /// or skipped. Marks the plan as user-initiated.
    private func replanRestOfToday(_ plan: DailyPlan) {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            guard PremiumGateService.canGeneratePlan() else { return }

            let goals = (profile?.goals ?? nil) ?? []
            let maxActions = profile?.workStylePreference?.maxActionsPerDay ?? 6

            // Remember how many slots the settled (done/skipped) actions consumed
            // so the fresh batch is sized to what remains.
            let settled = (plan.actions ?? []).filter { $0.statusRaw != "pending" }
            let remainingSlots = max(1, maxActions - settled.count)

            // Drop the pending actions only.
            for action in (plan.actions ?? []) where action.statusRaw == "pending" {
                modelContext.delete(action)
            }
            plan.actions = (plan.actions ?? []).filter { $0.statusRaw != "pending" }

            await populate(plan, goals: goals, maxActions: remainingSlots)

            plan.regenerated = true
            try? modelContext.save()
            PremiumGateService.recordPlanGeneration()
            Haptics.medium()
        }
    }

    /// Carries a pending action forward to tomorrow's plan (creating tomorrow's
    /// plan if needed), marking the original skipped today. Preserves the goal
    /// lineage + milestone link via the carriedOverFrom marker.
    private func moveToTomorrow(_ action: PlannedAction) {
        Haptics.light()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now

        // Get-or-create tomorrow's plan.
        let tomorrowPlan: DailyPlan
        if let existing = plans.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) }) {
            tomorrowPlan = existing
        } else {
            let format = PlanFormat(rawValue: action.plan?.formatRaw ?? "") ?? .focusBlocks
            let created = DailyPlan(date: tomorrow, format: format)
            modelContext.insert(created)
            tomorrowPlan = created
        }

        // Idempotency: don't duplicate the same title carried from today.
        let originDate = action.plan?.date ?? Calendar.current.startOfDay(for: .now)
        let alreadyThere = (tomorrowPlan.actions ?? []).contains {
            $0.carriedOverFrom == originDate && $0.title == action.title
        }
        if !alreadyThere {
            let clone = PlannedAction(
                title: action.title,
                why: action.whyReasoning,
                timeSlot: action.timeSlot,
                duration: action.durationMinutes,
                goalID: action.goalID,
                goalTitleSnapshot: action.goalTitleSnapshot,
                loggedAmount: action.loggedAmount,
                milestone: action.milestone,
                carriedOverFrom: originDate,
                cueTrigger: action.cueTrigger,
                targetAmount: action.targetAmount,
                targetUnit: action.targetUnit,
                anchorType: action.anchorType,
                scheduleCue: action.scheduleCue
            )
            modelContext.insert(clone)
            clone.plan = tomorrowPlan
            tomorrowPlan.actionCount = (tomorrowPlan.actions ?? []).count
        }

        // Retire the original on today's plan.
        action.statusRaw = "skipped"
        try? modelContext.save()
    }

    // MARK: - Done handling (C1 milestone credit preserved)

    private func handleDone(_ action: PlannedAction) {
        let goals = (profile?.goals ?? nil) ?? []
        if let goalID = action.goalID {
            if let goal = goals.first(where: { $0.id == goalID }) {
                // For measurable goals, move the number: record() creates a
                // ProgressLog, updates currentValue, bumps lastProgressDate and
                // the streak, and fires regression/pace logic.
                if goal.hasTarget, let amount = action.loggedAmount, amount != 0 {
                    ProgressLogService.record(
                        goal: goal,
                        amount: amount,
                        source: .action,
                        note: action.title,
                        context: modelContext
                    )
                } else {
                    // Non-measurable completion: cadence-aware streak + a
                    // zero-amount log so weekly adherence reflects the touch.
                    ProgressLogService.logCheckIn(goal: goal, source: .action, context: modelContext)
                }
            }
        } else if action.anchorKind == .goalWork {
            // Only goal-work without an explicit goalID falls back to title-match.
            // Fixed anchors + routines (sleep, meals, cooking) credit no goal.
            for goal in goals {
                let temps = PlanGenerator.templates(for: goal.domain)
                if temps.contains(where: { $0.0 == action.title }) {
                    ProgressLogService.logCheckIn(goal: goal, source: .action, context: modelContext)
                    break
                }
            }
        }

        // C1/C2 — credit the checkpoint chain. Roll the action's logged amount (or
        // a single unit) up the parentMilestone chain via the service whenever the
        // action is linked to ANY milestone — not only when the leaf node itself
        // carries a target. The week/month planning node is intentionally
        // target-less (C2), but its targeted month/quarter/year ancestors must
        // still be credited; contribute() already rolls the number only into
        // ancestors that hasTarget, so a target-less leaf is a safe no-op locally
        // while propagating up the chain. Runs in ADDITION to the goalID credit +
        // cadence logCheckIn above.
        if let milestone = action.milestone {
            let amount = (action.loggedAmount.map { $0 != 0 ? $0 : 1 }) ?? 1
            MilestoneProgressService.contribute(amount: amount, to: milestone, context: modelContext)
        }

        // LEARNING (build-order #3) — make logging mostly automatic: a Done block with
        // a resolvable timeSlot becomes an inferred ActualEvent so the on-device
        // LearningService has real data to adapt durations / wake-sleep / adherence,
        // even for the dominant tap-Done flow. De-dupe on linkedActionID so re-marking
        // (or a manual BlockLogSheet log) never piles up a second actual.
        recordInferredActual(for: action)

        try? modelContext.save()
    }

    /// Insert an `inferred` `ActualEvent` for a just-completed action, unless one is
    /// already logged against this block (manual or inferred). Pure de-dupe by
    /// `linkedActionID`; the surrounding `handleDone` owns the save.
    private func recordInferredActual(for action: PlannedAction) {
        let actionID = action.id
        let existing = FetchDescriptor<ActualEvent>(
            predicate: #Predicate { $0.linkedActionID == actionID }
        )
        let already = ((try? modelContext.fetch(existing)) ?? []).isEmpty == false
        guard !already else { return }
        if let ev = LearningService.inferredEvent(from: action, on: action.plan?.date ?? .now) {
            modelContext.insert(ev)
        }
    }
}

// MARK: - Add Action Sheet (manual PlannedAction)

/// A small sheet to add a manual `PlannedAction` to an existing plan: title,
/// duration, time slot, and an optional goal. Links the action to the goal's
/// current week Milestone so manual work also rolls up the C1 chain.
private struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    let plan: DailyPlan
    let goals: [Goal]

    @State private var title = ""
    @State private var timeSlot = ""
    @State private var durationMinutes = 30
    @State private var selectedGoalID: UUID?

    private var activeGoals: [Goal] { goals.filter(\.isActive) }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Action")
                            TextField("What will you do?", text: $title)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink)
                            t.rule.frame(height: 1)
                        }

                        // Time + duration
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(title: "Time (optional)")
                                TextField("e.g. 14:00", text: $timeSlot)
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundStyle(t.ink)
                                t.rule.frame(height: 1)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(title: "Minutes")
                                Stepper(value: $durationMinutes, in: 5...240, step: 5) {
                                    Text("\(durationMinutes)m")
                                        .font(.system(size: 16, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundStyle(t.ink)
                                }
                                .tint(t.accent)
                            }
                        }

                        // Goal picker (optional)
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Toward (optional)")
                            VStack(spacing: 6) {
                                goalPickerRow(goal: nil, t: t)
                                ForEach(activeGoals) { goal in
                                    goalPickerRow(goal: goal, t: t)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func goalPickerRow(goal: Goal?, t: ResolvedTheme) -> some View {
        let isSelected = selectedGoalID == goal?.id
        Button {
            Haptics.selection()
            selectedGoalID = goal?.id
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(goal?.horizon.dotColor ?? t.faint)
                    .frame(width: 6, height: 6)
                Text(goal?.title ?? "No specific goal")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? t.bg : t.ink)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(t.bg)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? t.ink : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func add() {
        Haptics.success()
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let resolvedGoal = selectedGoalID.flatMap { gid in goals.first { $0.id == gid } }
        let action = PlannedAction(
            title: trimmed,
            why: "",
            timeSlot: timeSlot.trimmingCharacters(in: .whitespaces),
            duration: durationMinutes,
            goalID: resolvedGoal?.id,
            goalTitleSnapshot: resolvedGoal?.title,
            milestone: resolvedGoal.map { WeeklyPlanService.ensureWeekMilestone(for: $0, context: modelContext) }
        )
        modelContext.insert(action)
        action.plan = plan
        plan.actionCount = (plan.actions ?? []).count
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Reschedule Sheet (edit timeSlot)

/// A compact sheet to edit a pending action's time slot.
private struct RescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    @Bindable var action: PlannedAction
    @State private var timeSlot = ""

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "Action")
                        Text(action.title)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(t.ink)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "New time")
                        TextField("e.g. 16:30", text: $timeSlot)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(t.ink)
                        t.rule.frame(height: 1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        action.timeSlot = timeSlot.trimmingCharacters(in: .whitespaces)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear { timeSlot = action.timeSlot }
        }
        .presentationDetents([.height(240), .medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Skip Reason Sheet (#14 — capture why an action was skipped)

/// A compact, non-intrusive sheet shown when the user skips an action. Offers a
/// short menu of common reasons plus an optional free-text note, then marks the
/// action skipped and stores the reason in `PlannedAction.skipReason` so
/// SkipAnalysisService and the adaptive planner can learn from real reasons.
private struct SkipReasonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    @Bindable var action: PlannedAction
    @State private var selectedReason: String?
    @State private var note = ""

    /// The canonical skip-reason categories SkipAnalysisService can pattern-match.
    /// Raw values are stable, lowercase keys; labels are the user-facing strings.
    private static let commonReasons: [(key: String, label: String)] = [
        ("no_time", "Not enough time"),
        ("not_feeling_it", "Not feeling it"),
        ("priority_shift", "Something more important came up"),
        ("too_hard", "Felt too big / hard"),
        ("did_differently", "Did it a different way"),
        ("other", "Other"),
    ]

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Skipping")
                            Text(action.title)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "What got in the way?")
                            VStack(spacing: 6) {
                                ForEach(Self.commonReasons, id: \.key) { reason in
                                    reasonRow(reason, t: t)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Note (optional)")
                            TextField("Anything else?", text: $note, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundStyle(t.ink)
                                .lineLimit(2...4)
                            t.rule.frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Why skip?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skip") { confirmSkip() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func reasonRow(_ reason: (key: String, label: String), t: ResolvedTheme) -> some View {
        let isSelected = selectedReason == reason.key
        Button {
            Haptics.selection()
            selectedReason = reason.key
        } label: {
            HStack(spacing: 8) {
                Text(reason.label)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? t.bg : t.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(t.bg)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? t.ink : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Persists the chosen reason (label + optional note) into skipReason and
    /// marks the action skipped. A skip with no reason selected still records the
    /// note (or nothing), so the flow is never blocking.
    private func confirmSkip() {
        Haptics.light()
        let label = Self.commonReasons.first { $0.key == selectedReason }?.label
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined: String?
        switch (label, trimmedNote.isEmpty) {
        case (let l?, false): combined = "\(l) — \(trimmedNote)"
        case (let l?, true):  combined = l
        case (nil, false):    combined = trimmedNote
        case (nil, true):     combined = nil
        }
        action.skipReason = combined
        action.statusRaw = "skipped"
        try? modelContext.save()
        dismiss()
    }
}
