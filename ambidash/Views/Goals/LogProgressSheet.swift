import SwiftUI
import SwiftData

/// Quantitative logging sheet for measurable goals (goal.hasTarget).
/// Lets the user record a new absolute value or add an increment, shows the
/// current/target/on-pace readouts, a sparkline of real logged values, and a
/// pace variance pill.
struct LogProgressSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal

    private enum LogMode: Hashable { case setValue, addAmount }
    @State private var mode: LogMode = .setValue
    @State private var entry: String = ""

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

                // Header (mirrors GoalQuickSheet horizon-dot + serif title)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(goal.horizon.dotColor).frame(width: 6, height: 6)
                        Text(goal.horizon.displayName.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(t.muted)
                        Spacer()
                        VariancePill(variance: TargetMath.variance(goal))
                    }

                    Text(goal.title)
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .tracking(-0.3)
                        .foregroundStyle(t.ink)
                }
                .padding(.horizontal, 22)

                // Readouts
                VStack(spacing: 0) {
                    DataRowView(label: "Current", value: MetricFormat.number(goal.currentValue), unit: unitLabel)
                    DataRowView(label: "Target", value: MetricFormat.number(goal.targetValue), unit: unitLabel)
                    DataRowView(label: "On pace, need", value: MetricFormat.number(TargetMath.expectedValue(goal)), unit: unitLabel)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                // Sparkline of real logged values
                let values = TargetMath.recentValues(for: goal, days: 14)
                if values.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Logged values")
                        SparklineView(values: values, width: 280, height: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }

                // Mode segmented control
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(title: "Log progress")
                    HStack(spacing: 6) {
                        modeButton(.setValue, label: "Set new value", t: t)
                        modeButton(.addAmount, label: "Add amount", t: t)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                // Numeric entry
                VStack(alignment: .leading, spacing: 6) {
                    TextField(placeholder, text: $entry)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(t.ink)
                    t.rule.frame(height: 1)

                    if let preview = previewValue {
                        Text("New value: \(MetricFormat.value(preview, unit: goal.unit))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(t.muted)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)

                // Save
                PrimaryButton(label: "Save progress") {
                    save()
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 24)
                .disabled(parsedEntry == nil)
                .opacity(parsedEntry == nil ? 0.4 : 1)
            }
        }
        .background(t.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
    }

    private var unitLabel: String? {
        goal.unit.isEmpty ? nil : goal.unit
    }

    private var placeholder: String {
        switch mode {
        case .setValue: return goal.unit.isEmpty ? "New value" : "New value in \(goal.unit)"
        case .addAmount: return goal.unit.isEmpty ? "Amount to add" : "Amount in \(goal.unit)"
        }
    }

    private var parsedEntry: Double? {
        Double(entry.trimmingCharacters(in: .whitespaces))
    }

    /// The resulting absolute value if saved now.
    private var previewValue: Double? {
        guard let v = parsedEntry else { return nil }
        switch mode {
        case .setValue: return v
        case .addAmount: return goal.currentValue + v
        }
    }

    @ViewBuilder
    private func modeButton(_ target: LogMode, label: String, t: ResolvedTheme) -> some View {
        let isSelected = mode == target
        Button {
            Haptics.selection()
            mode = target
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? t.bg : t.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? t.ink : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let v = parsedEntry else { return }
        Haptics.success()
        switch mode {
        case .setValue:
            ProgressLogService.record(goal: goal, newValue: v, source: .manual, context: modelContext)
        case .addAmount:
            ProgressLogService.record(goal: goal, amount: v, source: .manual, context: modelContext)
        }
        try? modelContext.save()
        dismiss()
    }
}
