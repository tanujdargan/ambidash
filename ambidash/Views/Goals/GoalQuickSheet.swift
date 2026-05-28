import SwiftUI
import SwiftData

struct GoalQuickSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal

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
                DataRowView(label: "Neglect", value: "\(goal.neglectDays)", unit: "days")
                if let streak = goal.streak, streak.currentCount > 0 {
                    DataRowView(label: "Streak", value: "\(streak.currentCount)", unit: "days")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .fadeSlideIn(delay: 0.1)

            // Actions
            VStack(spacing: 10) {
                PrimaryButton(label: "Log progress") {
                    Haptics.success()
                    goal.lastProgressDate = .now
                    goal.streak?.recordActivity()
                    try? modelContext.save()
                    dismiss()
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
    }
}
