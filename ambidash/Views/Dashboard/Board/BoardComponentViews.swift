import SwiftUI

/// The component renderers for the configurable board. Each is a stateless wrapper
/// around an EXISTING dashboard surface, reading exclusively from the injected
/// `BoardData` value struct (compute-once at board level — no per-component
/// @Query). They reuse the shared card chrome + components from Components.swift so
/// the board keeps the dashboard's visual rhythm and all current behavior:
/// tap-score → breakdown, tap-goal → detail, three live latest goals.

// MARK: - Composite Score

/// BigNumber + sparkline. Tapping opens the composite breakdown sheet (preserved
/// via `onTapScore`). Mirrors DashboardView's composite block (formerly lines
/// 97–126).
struct CompositeScoreComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData
    let onTapScore: (ScoreBreakdownTarget) -> Void

    var body: some View {
        let t = tm.resolved
        Button {
            Haptics.selection()
            onTapScore(.composite)
        } label: {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(title: "Composite")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(boardData.compositeScore)")
                            .font(.system(size: 56, design: .monospaced))
                            .monospacedDigit()
                            .tracking(-2)
                            .foregroundStyle(t.ink)
                        Text("/100")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(t.faint)
                    }
                }
                Spacer()
                SparklineView(values: boardData.compositeHistory, width: 120, height: 48)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Composite score: \(boardData.compositeScore) out of 100. Tap for breakdown.")
    }
}

// MARK: - Vitals Grid

/// 3-col grid of ArcGauges, one per LifeDimension. Each taps to its dimension
/// breakdown (preserved via `onTapScore`). Mirrors DashboardView's gauge grid
/// (formerly lines 130–148).
struct VitalsGridComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData
    /// Which dimensions to show (the "pick your vitals" config). Defaults to all.
    var config: ComponentConfig.Vitals = .default
    let onTapScore: (ScoreBreakdownTarget) -> Void

    var body: some View {
        let dimensions = config.resolvedDimensions
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 18) {
            ForEach(Array(dimensions.enumerated()), id: \.element) { index, dim in
                Button {
                    Haptics.selection()
                    onTapScore(.dimension(dim))
                } label: {
                    ArcGauge(
                        value: Double(boardData.dimensionScores[dim] ?? 50) / 100.0,
                        size: 86,
                        strokeWidth: 3.5,
                        label: dim.displayName
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .staggeredAppear(index: index)
            }
        }
    }
}

// MARK: - Sparkline History

/// A wider standalone composite-history sparkline with a section label. Reuses the
/// shared SparklineView; complements the inline sparkline in the composite block.
struct SparklineHistoryComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "History · 14d")
            GeometryReader { geo in
                SparklineView(values: boardData.compositeHistory, width: geo.size.width, height: 56)
            }
            .frame(height: 56)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityLabel("Composite history over the last 14 days")
    }
}

// MARK: - Latest Goals

/// The three most-recently-active goals as compact, tappable cards. Each drills
/// into GoalDetailView via NavigationLink (the board is hosted in a NavigationStack
/// so this works as before). Reuses LatestGoalCard chrome. Mirrors DashboardView's
/// latestGoalsSection (formerly lines 245–272).
struct LatestGoalsComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    var body: some View {
        let t = tm.resolved
        if !boardData.latestGoals.isEmpty {
            VStack(alignment: .leading, spacing: t.space.component) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(title: "Latest goals")
                    Spacer()
                    Text("Most recently active")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                VStack(spacing: 8) {
                    ForEach(Array(boardData.latestGoals.enumerated()), id: \.element.id) { index, goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            LatestGoalCard(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                        .staggeredAppear(index: index)
                    }
                }
            }
        }
    }
}

// MARK: - Today, Narrow

/// A tight view of the next few planned actions, or a fallback of free time /
/// sleep / steps. Reuses DataRowView. Mirrors DashboardView's "Today, narrow"
/// block (formerly lines 162–174).
struct TodayNarrowComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData
    /// How many planned actions to show. Defaults to 3.
    var config: ComponentConfig.Today = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "Today, narrow")
            if let plan = boardData.todayPlan, !(plan.actions ?? []).isEmpty {
                let topActions = (plan.actions ?? []).sorted { $0.timeSlot < $1.timeSlot }.prefix(config.resolvedRowCount)
                ForEach(Array(topActions), id: \.id) { action in
                    DataRowView(label: action.title, value: action.timeSlot, unit: "\(action.durationMinutes)m")
                }
            } else {
                DataRowView(label: "Free time", value: "\(boardData.todaySnapshot?.calendarFreeMinutes ?? 0)", unit: "min")
                DataRowView(label: "Sleep", value: String(format: "%.1f", boardData.todaySnapshot?.sleepHours ?? 0), unit: "hr")
                DataRowView(label: "Steps", value: "\(boardData.todaySnapshot?.steps ?? 0)")
            }
        }
    }
}

// MARK: - Mentor

/// One surfaced insight (AI or local pattern). Wraps the existing InsightCardView,
/// which manages its own AI fetch lifecycle. Mirrors DashboardView's mentor block
/// (formerly lines 157–159).
struct MentorComponent: View {
    let boardData: BoardData

    var body: some View {
        InsightCardView(goals: boardData.activeGoals, snapshot: boardData.todaySnapshot)
    }
}

// MARK: - Identity Line

/// "You are becoming…" derived from the lowest dimension. Promotes the previously
/// implicit `identityText` into a visible surface, reusing the IdentityStatement
/// chrome.
struct IdentityLineComponent: View {
    let boardData: BoardData

    var body: some View {
        IdentityStatement(text: boardData.identityText)
    }
}

// MARK: - Reflection Prompt

/// A gentle, deterministic prompt to close the day with. Picks a stable question
/// from the lowest-dimension context so it stays consistent within a render cycle.
struct ReflectionPromptComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Reflection")
            Text(prompt)
                .font(.system(size: 18, weight: tm.typography.serifWeight, design: .serif))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(t.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityLabel("Reflection prompt: \(prompt)")
    }

    private var prompt: String {
        switch boardData.lowestDimension {
        case .body: return "Where did your body ask for something today — and did you listen?"
        case .mind: return "What thought ran you today that you'd rather run yourself?"
        case .craft: return "What did you make today that wasn't here yesterday?"
        case .people: return "Who got your real attention today?"
        case .wealth: return "What did today cost you, and was it worth it?"
        case .adventure: return "When did you feel most alive today?"
        case nil: return "What is one loop you can close before sleep?"
        }
    }
}

// MARK: - Streaks

/// A compact summary of active streaks: the total count, the longest current run,
/// and any streaks at risk today. Reads the pre-computed `StreakService.StreakSummary`
/// from `BoardData` (no per-component @Query). Deliberately NOT placed on the Calm
/// template so the ND-friendly default carries no streak pressure.
struct StreaksComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    private var summary: StreakService.StreakSummary { boardData.streakSummary }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Streaks")

            HStack(spacing: 20) {
                stat(value: "\(summary.totalActiveStreaks)", label: "active", t: t)
                stat(value: "\(summary.longestCurrentStreak)", label: "longest", t: t)
            }

            if !summary.atRiskStreaks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(summary.atRiskStreaks.prefix(3).enumerated()), id: \.offset) { _, risk in
                        HStack(spacing: 6) {
                            // Non-punitive: a streak "at risk" is a gentle time cue,
                            // not an alarm — a soft accent clock, never a red warning.
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(t.accent)
                            Text(risk.goalTitle)
                                .font(.system(size: 12))
                                .foregroundStyle(t.muted)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(risk.count)d")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                    }
                }
            } else if summary.totalActiveStreaks == 0 {
                Text("No streaks going yet — log progress to start one.")
                    .font(.system(size: 12))
                    .foregroundStyle(t.faint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.totalActiveStreaks) active streaks, longest \(summary.longestCurrentStreak) days.")
    }

    @ViewBuilder
    private func stat(value: String, label: String, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(t.accent)
                Text(value)
                    .font(.system(size: 26, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.ink)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(t.faint)
        }
    }
}

// MARK: - Unavailable (fallback)

/// Rendered for any `ComponentKind` this build doesn't understand (`.unknown`),
/// so a board synced from a newer client degrades gracefully instead of crashing.
struct UnavailableComponentCard: View {
    @Environment(ThemeManager.self) private var tm
    let kindRaw: String

    var body: some View {
        let t = tm.resolved
        HStack(spacing: 10) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 16))
                .foregroundStyle(t.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unavailable component")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(t.ink)
                Text(kindRaw.isEmpty ? "Update the app to view this." : "\"\(kindRaw)\" — update the app to view this.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityLabel("Unavailable component. Update the app to view this.")
    }
}
