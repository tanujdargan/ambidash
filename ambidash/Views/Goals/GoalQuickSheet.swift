import SwiftUI
import SwiftData

struct GoalQuickSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal
    @State private var showLogProgress = false

    var body: some View {
        let t = tm.resolved
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

                    GhostButton(label: "Quietly retire") {
                        Haptics.light()
                        goal.isActive = false
                        try? modelContext.save()
                        dismiss()
                    }
                }

                GhostButton(label: "Move to top priority") {
                    Haptics.medium()
                    goal.priority = 0
                    try? modelContext.save()
                    dismiss()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .fadeSlideIn(delay: 0.2)
        }
        .background(t.bg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
        .sheet(isPresented: $showLogProgress) {
            LogProgressSheet(goal: goal)
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
