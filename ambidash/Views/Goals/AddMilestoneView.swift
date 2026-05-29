import SwiftUI
import SwiftData

/// Create or edit a single `Milestone`. Mirrors `AddGoalView`'s form structure and
/// the horizon dot-button picker block (swapping `GoalHorizon` for `MilestonePeriod`).
/// On Save it inserts the milestone, wires the `goal` / `parentMilestone` inverses
/// from the child side, and persists. Presented at the medium detent.
struct AddMilestoneView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    /// The goal this checkpoint belongs to.
    let goal: Goal
    /// Optional coarser checkpoint this one nests under (the tree parent).
    let parent: Milestone?
    /// When editing an existing checkpoint; nil for a fresh create.
    let editing: Milestone?

    @State private var title = ""
    @State private var detail = ""
    @State private var selectedPeriod: MilestonePeriod = .month
    @State private var startDate: Date = .now
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now

    // Optional measurable key-result for this checkpoint.
    @State private var hasTarget = false
    @State private var targetText = ""
    @State private var unitText = ""

    init(goal: Goal, parent: Milestone? = nil, editing: Milestone? = nil) {
        self.goal = goal
        self.parent = parent
        self.editing = editing
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Checkpoint")
                            TextField("What outcome marks this checkpoint?", text: $title)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink)
                            t.rule.frame(height: 1)
                        }

                        // Detail
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Detail (optional)")
                            TextField("How you'll know it's done", text: $detail, axis: .vertical)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(t.ink2)
                                .lineLimit(1...4)
                            t.rule.frame(height: 1)
                        }

                        // Parent context (read-only)
                        if let parent {
                            HStack(spacing: 8) {
                                Circle().fill(parent.period.dotColor).frame(width: 6, height: 6)
                                Text("Nested under")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(t.faint)
                                Text(parent.title)
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(t.muted)
                                    .lineLimit(1)
                            }
                        }

                        // Period picker — copies the horizon dot-button row.
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Cadence band")
                            HStack(spacing: 8) {
                                ForEach(MilestonePeriod.allCases) { period in
                                    let isSelected = selectedPeriod == period
                                    Button {
                                        Haptics.selection()
                                        selectedPeriod = period
                                        snapWindow(to: period)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(period.dotColor)
                                                .frame(width: 8, height: 8)
                                            Text(period.displayName)
                                                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                                                .foregroundStyle(isSelected ? t.ink : t.muted)
                                            Text(period.timeframe)
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

                        // Date window
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Window")
                            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                                .font(.system(size: 14))
                                .foregroundStyle(t.ink)
                                .tint(t.accent)
                            DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .font(.system(size: 14))
                                .foregroundStyle(t.ink)
                                .tint(t.accent)
                        }

                        // Optional measurable target (collapsible).
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $hasTarget.animation(.easeInOut(duration: 0.2))) {
                                VStack(alignment: .leading, spacing: 2) {
                                    SectionLabel(title: "Measurable key-result")
                                    Text("A number this checkpoint should reach")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(t.faint)
                                }
                            }
                            .tint(t.accent)
                            .onChange(of: hasTarget) { _, _ in Haptics.selection() }

                            if hasTarget {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SectionLabel(title: "Target")
                                        TextField("0", text: $targetText)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 16, design: .monospaced))
                                            .monospacedDigit()
                                            .foregroundStyle(t.ink)
                                        t.rule.frame(height: 1)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        SectionLabel(title: "Unit (optional)")
                                        TextField("e.g. lbs · pages", text: $unitText)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(t.ink2)
                                        t.rule.frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(editing == nil ? "Add Checkpoint" : "Edit Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Setup

    /// Populates fields from the editing target (or seeds a sensible default
    /// window from the parent / goal horizon for a fresh create).
    private func hydrate() {
        if let editing {
            title = editing.title
            detail = editing.detail
            selectedPeriod = editing.period
            startDate = editing.startDate
            endDate = editing.endDate
            if let tv = editing.targetValue {
                hasTarget = true
                targetText = MetricFormat.number(tv)
            }
            unitText = editing.unit
            return
        }

        // Fresh create: pick the next-finer band under the parent (or the
        // coarsest band of the goal's horizon when there is no parent) and snap
        // the window to it.
        if let parent {
            selectedPeriod = nextFinerBand(after: parent.period)
        } else {
            selectedPeriod = MilestoneGenerator.chainPeriods(for: goal.horizon).first ?? .month
        }
        unitText = goal.unit
        snapWindow(to: selectedPeriod)
    }

    /// The next finer cadence band below `period` (year→quarter→month→week),
    /// clamped at week.
    private func nextFinerBand(after period: MilestonePeriod) -> MilestonePeriod {
        switch period {
        case .year: return .quarter
        case .quarter: return .month
        case .month: return .week
        case .week: return .week
        }
    }

    /// Snaps the start/end window to the calendar window of `period` containing
    /// now, matching `MilestoneGenerator.window` so manual and auto-generated
    /// checkpoints line up.
    private func snapWindow(to period: MilestonePeriod) {
        let win = MilestoneGenerator.window(for: period, containing: .now)
        startDate = win.start
        endDate = win.end
    }

    // MARK: - Save

    private func save() {
        Haptics.success()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unitText.trimmingCharacters(in: .whitespaces)
        let target: Double? = hasTarget
            ? Double(targetText.trimmingCharacters(in: .whitespaces))
            : nil

        if let editing {
            // Edit in place — preserve currentValue / completion.
            editing.title = trimmedTitle
            editing.detail = trimmedDetail
            editing.period = selectedPeriod
            editing.startDate = startDate
            editing.endDate = endDate
            editing.targetValue = target
            if target != nil, editing.currentValue == nil {
                editing.currentValue = 0
            }
            if target == nil {
                editing.currentValue = nil
            }
            editing.unit = trimmedUnit
            MilestoneProgressService.refreshStatus(of: editing)
        } else {
            let milestone = Milestone(
                title: trimmedTitle,
                period: selectedPeriod,
                startDate: startDate,
                endDate: endDate,
                detail: trimmedDetail,
                targetValue: target,
                currentValue: target == nil ? nil : 0,
                unit: trimmedUnit,
                sortIndex: (goal.milestones ?? []).count
            )
            modelContext.insert(milestone)
            // Wire the inverses from the child side.
            milestone.goal = goal
            milestone.parentMilestone = parent
            MilestoneProgressService.refreshStatus(of: milestone)
            MilestoneProgressService.propagateStatus(from: milestone)
        }

        try? modelContext.save()
        dismiss()
    }
}
