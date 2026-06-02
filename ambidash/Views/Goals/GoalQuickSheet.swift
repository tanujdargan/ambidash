import SwiftUI
import SwiftData

struct GoalQuickSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal
    @State private var showLogProgress = false
    @State private var showRoadmap = false
    @State private var showDeleteConfirm = false
    // Inline edit state for goal.details (editable anytime, persists to CloudKit).
    @State private var editingDetails = false
    @State private var detailsDraft = ""
    @FocusState private var detailsFocused: Bool

    /// The next upcoming (not-yet-completed) checkpoint by end date, for the
    /// compact preview on the Roadmap row.
    private var nextMilestone: Milestone? {
        (goal.milestones ?? [])
            .filter { !$0.isCompleted }
            .min { $0.endDate < $1.endDate }
    }

    var body: some View {
        let t = tm.resolved
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(t.faint)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(goal.horizon.dotColor).frame(width: 6, height: 6)
                    Text(goal.horizon.displayName.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(t.muted)
                    GoalTypeChip(type: goal.goalType, theme: t)
                }

                Text(goal.title)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .tracking(-0.3)
                    .foregroundStyle(t.ink)

                if !goal.subtitle.isEmpty {
                    Text(goal.subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.muted)
                }
            }
            .padding(.horizontal, 22)
            .fadeSlideIn(delay: 0)

            // Stats
            VStack(spacing: 0) {
                DataRowView(label: "Health", value: goal.computedStatus.label)
                if goal.isHabitual {
                    DataRowView(label: "Adherence", value: AdherenceFormat.fraction(for: goal))
                } else {
                    DataRowView(label: "Neglect", value: "\(goal.neglectDays)", unit: "days")
                }
                if let streak = goal.streak, streak.currentCount > 0 {
                    DataRowView(label: "Streak", value: "\(streak.currentCount)", unit: "days")
                }
                if goal.hasTarget {
                    DataRowView(
                        label: "Progress",
                        value: "\(MetricFormat.number(goal.currentValue)) / \(MetricFormat.number(goal.targetValue))",
                        unit: goal.unit.isEmpty ? nil : goal.unit
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .fadeSlideIn(delay: 0.1)

            // How you'll do it — inline-editable goal description.
            detailsSection(t)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .fadeSlideIn(delay: 0.12)

            if goal.hasTarget {
                TargetProgressBar(goal: goal, maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .fadeSlideIn(delay: 0.15)
            } else if goal.isHabitual {
                AdherenceBar(goal: goal, maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .fadeSlideIn(delay: 0.15)
            }

            // Roadmap entry + next-checkpoint preview
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.selection()
                    showRoadmap = true
                } label: {
                    HStack(spacing: 8) {
                        SectionLabel(title: "Roadmap")
                        Spacer()
                        if let next = nextMilestone {
                            StatusDot(status: next.status)
                            Text(next.title)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(t.muted)
                                .lineLimit(1)
                            Text(next.endDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(t.faint)
                        } else {
                            Text((goal.milestones ?? []).isEmpty ? "Map this goal" : "\((goal.milestones ?? []).count) checkpoints")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(t.muted)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(t.faint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .fadeSlideIn(delay: 0.18)

            // Actions
            VStack(spacing: 10) {
                PrimaryButton(label: logButtonLabel) {
                    if goal.hasTarget {
                        Haptics.light()
                        showLogProgress = true
                    } else {
                        Haptics.success()
                        logCheckIn()
                        dismiss()
                    }
                }

                HStack(spacing: 10) {
                    GhostButton(label: goal.isActive ? "Pause" : "Resume") {
                        Haptics.light()
                        goal.isActive.toggle()
                        try? modelContext.save()
                        dismiss()
                    }

                    // Pause and "quietly retire" produced the identical isActive=false
                    // state, so the second action is a real DELETE instead — the only
                    // way to remove a mistakenly-added goal. Confirmed before deleting.
                    GhostButton(label: "Delete goal") {
                        Haptics.light()
                        showDeleteConfirm = true
                    }
                }

                GhostButton(label: "Move to top priority") {
                    Haptics.medium()
                    goal.priority = 0
                    try? modelContext.save()
                    dismiss()
                }

                // v4: pin/unpin to the always-visible Sticky Notes surface.
                GhostButton(label: goal.isSticky ? "Unpin sticky note" : "Pin as sticky note") {
                    Haptics.light()
                    goal.isSticky.toggle()
                    try? modelContext.save()
                }
                .accessibilityIdentifier("goal.toggleSticky")
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .fadeSlideIn(delay: 0.2)
        }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(t.bg)
        // Allow growing to large so the details editor + keyboard have room.
        .presentationDetents(editingDetails ? [.large] : [.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
        .sheet(isPresented: $showLogProgress) {
            LogProgressSheet(goal: goal)
        }
        .sheet(isPresented: $showRoadmap) {
            NavigationStack {
                GoalRoadmapView(goal: goal)
            }
        }
        .alert("Delete this goal?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Haptics.medium()
                modelContext.delete(goal)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes \"\(goal.title)\" and its progress. This cannot be undone.")
        }
    }

    /// Compact, inline-editable rendering of `goal.details`. Mirrors
    /// GoalDetailView's editor; Save persists to SwiftData → CloudKit.
    @ViewBuilder
    private func detailsSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(t.muted)
                    }
                    .accessibilityLabel(goal.details.isEmpty ? "Add details" : "Edit details")
                }
            }

            if editingDetails {
                TextEditor(text: $detailsDraft)
                    .focused($detailsFocused)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(t.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 70, maxHeight: 110)
                    .padding(8)
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
                    .font(.system(size: 13, design: .serif))
                    .italic(!goal.details.isEmpty)
                    .foregroundStyle(goal.details.isEmpty ? t.faint : t.ink2)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var logButtonLabel: String {
        goal.isHabitual ? "Log today" : "Log progress"
    }

    /// Records a non-measurable check-in: marks today as touched, advances the
    /// streak (cadence-aware for habitual goals), and writes a zero-amount log so
    /// weekly adherence reflects the touch.
    private func logCheckIn() {
        ProgressLogService.logCheckIn(goal: goal, source: .manual, context: modelContext)
        try? modelContext.save()
    }
}
