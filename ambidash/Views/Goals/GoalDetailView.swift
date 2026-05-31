import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal
    @State private var showLogProgress = false
    // Inline edit state for goal.details (Phase 2 left details creation-only;
    // this makes it editable anytime, persisting to SwiftData → CloudKit).
    @State private var editingDetails = false
    @State private var detailsDraft = ""
    @FocusState private var detailsFocused: Bool

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(goal.horizon.dotColor).frame(width: 8, height: 8)
                            Text(goal.horizon.displayName.uppercased() + " · " + goal.horizon.timeframe)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(t.muted)
                        }

                        Text(goal.title)
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .tracking(-0.3)
                            .foregroundStyle(t.ink)

                        if !goal.subtitle.isEmpty {
                            Text(goal.subtitle)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(t.muted)
                        }
                    }

                    // How you'll do it — the goal's clarifying description, with
                    // an inline editor that persists changes to SwiftData.
                    detailsSection(t)

                    // Pillar + type
                    HStack(spacing: 10) {
                        Image(systemName: goal.domain.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(t.accent)
                        Text(goal.domain.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(t.ink2)
                        Spacer()
                        GoalTypeChip(type: goal.goalType, theme: t)
                    }

                    HairlineRule()

                    // Status section
                    VStack(spacing: 0) {
                        DataRowView(label: "Health", value: goal.computedStatus.label)
                        if goal.isHabitual {
                            DataRowView(label: "Adherence", value: AdherenceFormat.fraction(for: goal))
                        } else {
                            DataRowView(label: "Days since progress", value: "\(goal.neglectDays)")
                        }
                        DataRowView(label: "Priority", value: "\(goal.priority)")
                        DataRowView(label: "Created", value: goal.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))

                        if let streak = goal.streak {
                            DataRowView(label: "Current streak", value: "\(streak.currentCount)", unit: "days")
                            DataRowView(label: "Best streak", value: "\(streak.bestCount)", unit: "days")
                        }
                    }

                    // Roadmap: link to the milestone tree + next-checkpoint preview.
                    roadmapSection(t)

                    // Cadence / adherence section for habitual goals
                    if goal.isHabitual {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionLabel(title: "Weekly cadence")
                                Spacer()
                                Text(cadenceCaption)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(t.faint)
                            }
                            AdherenceBar(goal: goal, maxWidth: .infinity)
                        }
                    }

                    // Measurable target section
                    if goal.hasTarget {
                        let unitLabel = goal.unit.isEmpty ? nil : goal.unit
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionLabel(title: "Measurable target")
                                Spacer()
                                VariancePill(variance: TargetMath.variance(goal))
                            }
                            TargetProgressBar(goal: goal, maxWidth: .infinity)
                        }

                        VStack(spacing: 0) {
                            DataRowView(label: "Baseline", value: MetricFormat.number(goal.baselineValue), unit: unitLabel)
                            DataRowView(label: "Current", value: MetricFormat.number(goal.currentValue), unit: unitLabel)
                            DataRowView(label: "Target", value: MetricFormat.number(goal.targetValue), unit: unitLabel)
                            DataRowView(label: "On pace, need", value: MetricFormat.number(TargetMath.expectedValue(goal)), unit: unitLabel)
                            DataRowView(label: "Complete", value: "\(Int((goal.percentComplete * 100).rounded()))", unit: "%")
                            DataRowView(label: "Pace", value: varianceLabel(TargetMath.variance(goal)))
                        }
                    }

                    // Progress trend
                    let trendValues: [Double] = goal.hasTarget
                        ? TargetMath.recentValues(for: goal, days: 14)
                        : GoalProgressTracker.recentScores(for: goal, days: 14).map { Double($0) }
                    if trendValues.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: goal.hasTarget ? "14-day logged values" : "14-day trend")
                            SparklineView(values: trendValues, width: 280, height: 40)
                        }
                    }

                    // Actions
                    VStack(spacing: 10) {
                        PrimaryButton(label: goal.isHabitual ? "Log today" : "Log progress") {
                            if goal.hasTarget {
                                Haptics.light()
                                showLogProgress = true
                            } else {
                                Haptics.success()
                                logCheckIn()
                            }
                        }

                        HStack(spacing: 10) {
                            PillButton(label: goal.isActive ? "Pause" : "Resume") {
                                goal.isActive.toggle()
                                try? modelContext.save()
                            }

                            PillButton(label: "Quietly retire") {
                                goal.isActive = false
                                try? modelContext.save()
                            }
                        }
                    }

                    // Horizon picker
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(title: "Time horizon")
                        HStack(spacing: 8) {
                            ForEach(GoalHorizon.allCases) { horizon in
                                let isSelected = goal.horizon == horizon
                                Button {
                                    Haptics.selection()
                                    goal.horizon = horizon
                                    try? modelContext.save()
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle().fill(horizon.dotColor).frame(width: 6, height: 6)
                                        Text(horizon.displayName)
                                            .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                                            .foregroundStyle(isSelected ? t.ink : t.muted)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
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
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogProgress) {
            LogProgressSheet(goal: goal)
        }
    }

    // MARK: - Details (how you'll do it)

    /// Shows `goal.details` like a workout description, with an inline edit
    /// affordance. Editing swaps to a fixed-height TextEditor with Save/Cancel so
    /// the keyboard stays contained; Save writes through to SwiftData → CloudKit.
    @ViewBuilder
    private func detailsSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title: "How you'll do it")
                Spacer()
                if !editingDetails {
                    Button {
                        Haptics.selection()
                        detailsDraft = goal.details
                        editingDetails = true
                        detailsFocused = true
                    } label: {
                        Image(systemName: goal.details.isEmpty ? "plus" : "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.muted)
                    }
                    .accessibilityLabel(goal.details.isEmpty ? "Add details" : "Edit details")
                }
            }

            if editingDetails {
                TextEditor(text: $detailsDraft)
                    .focused($detailsFocused)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(t.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88, maxHeight: 140)
                    .padding(10)
                    .background(t.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hair, lineWidth: 0.5))

                HStack(spacing: 10) {
                    PillButton(label: "Save", primary: true) {
                        Haptics.success()
                        goal.details = String(detailsDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
                        try? modelContext.save()
                        editingDetails = false
                        detailsFocused = false
                    }
                    PillButton(label: "Cancel") {
                        editingDetails = false
                        detailsFocused = false
                    }
                    Spacer()
                }
            } else {
                Text(goal.details.isEmpty ? "No details yet — tap + to describe how you'll do this." : goal.details)
                    .font(.system(size: 14, design: .serif))
                    .italic(!goal.details.isEmpty)
                    .foregroundStyle(goal.details.isEmpty ? t.faint : t.ink2)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Roadmap

    /// The next 1–2 upcoming (not-yet-completed) checkpoints by end date, used for
    /// the compact preview beneath the Roadmap link.
    private var upcomingMilestones: [Milestone] {
        (goal.milestones ?? [])
            .filter { !$0.isCompleted }
            .sorted { $0.endDate < $1.endDate }
            .prefix(2)
            .map { $0 }
    }

    @ViewBuilder
    private func roadmapSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                GoalRoadmapView(goal: goal)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(title: "Roadmap")
                        Text((goal.milestones ?? []).isEmpty
                            ? "Break this goal into a checkpoint chain"
                            : "\((goal.milestones ?? []).count) checkpoint\((goal.milestones ?? []).count == 1 ? "" : "s")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(t.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(t.faint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Compact preview of the next 1–2 checkpoints.
            if !upcomingMilestones.isEmpty {
                VStack(spacing: 0) {
                    ForEach(upcomingMilestones) { milestone in
                        HStack(spacing: 8) {
                            StatusDot(status: milestone.status)
                            Text(milestone.title)
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink2)
                                .lineLimit(1)
                            Spacer()
                            Text(milestone.endDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { HairlineRule() }
                    }
                }
            }
        }
    }

    private func varianceLabel(_ variance: TargetVariance) -> String {
        switch variance {
        case .ahead: return "Ahead"
        case .onTrack: return "On pace"
        case .behind: return "Behind"
        }
    }

    private var cadenceCaption: String {
        let n = max(goal.timesPerWeek, 1)
        if n >= 7 { return "every day" }
        if n == 1 { return "once a week" }
        return "\(n)× a week"
    }

    /// Records a non-measurable check-in: marks today as touched, advances the
    /// streak (cadence-aware for habitual goals), and writes a zero-amount log so
    /// weekly adherence reflects the touch.
    private func logCheckIn() {
        ProgressLogService.logCheckIn(goal: goal, source: .manual, context: modelContext)
        try? modelContext.save()
    }
}
