import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal
    @State private var showLogProgress = false

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

                    // Pillar
                    HStack(spacing: 10) {
                        Image(systemName: goal.domain.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(t.accent)
                        Text(goal.domain.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(t.ink2)
                    }

                    HairlineRule()

                    // Status section
                    VStack(spacing: 0) {
                        DataRowView(label: "Health", value: goal.computedStatus.label)
                        DataRowView(label: "Days since progress", value: "\(goal.neglectDays)")
                        DataRowView(label: "Priority", value: "\(goal.priority)")
                        DataRowView(label: "Created", value: goal.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))

                        if let streak = goal.streak {
                            DataRowView(label: "Current streak", value: "\(streak.currentCount)", unit: "days")
                            DataRowView(label: "Best streak", value: "\(streak.bestCount)", unit: "days")
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
                        PrimaryButton(label: "Log progress") {
                            if goal.hasTarget {
                                Haptics.light()
                                showLogProgress = true
                            } else {
                                Haptics.success()
                                goal.lastProgressDate = .now
                                goal.streak?.recordActivity()
                                try? modelContext.save()
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

    private func varianceLabel(_ variance: TargetVariance) -> String {
        switch variance {
        case .ahead: return "Ahead"
        case .onTrack: return "On pace"
        case .behind: return "Behind"
        }
    }
}
