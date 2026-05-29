import SwiftUI
import SwiftData

/// The per-goal decomposition surface: a long-range goal made visible as a
/// checkpoint chain (Year → Quarter → Month → Week). Shows the goal's Milestone
/// tree as an indented, period-grouped timeline, lets the user add/edit
/// checkpoints manually, or tap "Decompose with mentor" to AI-generate the chain
/// (falling back to `MilestoneGenerator.defaultChain` offline).
struct GoalRoadmapView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal

    @State private var isDecomposing = false
    @State private var addContext: AddContext?

    /// Wraps the parameters for presenting AddMilestoneView, so a single sheet
    /// item drives both "add root" and "add child" / "edit".
    private struct AddContext: Identifiable {
        let id = UUID()
        var parent: Milestone?
        var editing: Milestone?
    }

    /// Milestones ordered for display: coarse bands first, then by start date,
    /// then by sortIndex — the natural top-to-bottom reading of the chain.
    private var orderedMilestones: [Milestone] {
        goal.milestones.sorted { a, b in
            if a.period != b.period {
                return periodRank(a.period) < periodRank(b.period)
            }
            if a.startDate != b.startDate { return a.startDate < b.startDate }
            return a.sortIndex < b.sortIndex
        }
    }

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(t)

                    HairlineRule()

                    if goal.milestones.isEmpty {
                        emptyState(t)
                    } else {
                        chainTimeline(t)
                    }

                    actions(t)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addContext) { ctx in
            AddMilestoneView(goal: goal, parent: ctx.parent, editing: ctx.editing)
        }
    }

    // MARK: - Header (reuses GoalDetailView's horizon dot + serif title pattern)

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
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

            Text("The checkpoints between here and there.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(t.muted)
        }
        .fadeSlideIn(delay: 0)
    }

    // MARK: - Chain timeline (period-grouped bands)

    @ViewBuilder
    private func chainTimeline(_ t: ResolvedTheme) -> some View {
        let ordered = orderedMilestones
        VStack(alignment: .leading, spacing: 20) {
            ForEach(MilestonePeriod.allCases) { period in
                let band = ordered.filter { $0.period == period }
                if !band.isEmpty {
                    bandSection(period, milestones: band, t: t)
                }
            }
        }
    }

    @ViewBuilder
    private func bandSection(_ period: MilestonePeriod, milestones: [Milestone], t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(period.dotColor).frame(width: 6, height: 6)
                SectionLabel(title: period.displayName)
                Text("· \(period.timeframe)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                Spacer()
                Text("\(milestones.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    // Indent finer bands so the year > quarter > month > week
                    // nesting reads as a tree.
                    milestoneRow(milestone, t: t)
                        .padding(.leading, CGFloat(periodRank(milestone.period)) * 12)
                        .staggeredAppear(index: index)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneRow(_ milestone: Milestone, t: ResolvedTheme) -> some View {
        Button {
            Haptics.selection()
            addContext = AddContext(parent: milestone.parentMilestone, editing: milestone)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    StatusDot(status: milestone.status)
                    Text(milestone.title)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(milestone.isCompleted ? t.muted : t.ink)
                        .strikethrough(milestone.isCompleted, color: t.faint)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(milestone.endDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                if !milestone.detail.isEmpty {
                    Text(milestone.detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Measurable key-result rows + thin progress bar.
                if milestone.hasTarget {
                    let unitLabel = milestone.unit.isEmpty ? nil : milestone.unit
                    DataRowView(
                        label: "Progress",
                        value: "\(MetricFormat.number(milestone.currentValue ?? 0)) / \(MetricFormat.number(milestone.targetValue ?? 0))",
                        unit: unitLabel
                    )
                    milestoneProgressBar(milestone, t: t)
                }

                // Add-child affordance (only meaningful above the finest band).
                if milestone.period != .week {
                    HStack(spacing: 8) {
                        Spacer()
                        PillButton(label: "Add sub-checkpoint") {
                            Haptics.light()
                            addContext = AddContext(parent: milestone, editing: nil)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { HairlineRule() }
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    /// A thin track + fill at the checkpoint's percentComplete, mirroring
    /// TargetProgressBar's 6pt styling.
    @ViewBuilder
    private func milestoneProgressBar(_ milestone: Milestone, t: ResolvedTheme) -> some View {
        let pct = milestone.percentComplete
        let fill: Color = {
            switch milestone.status {
            case .onTrack: return t.ok
            case .needsAttention: return t.accent
            case .slipping: return t.danger
            case .paused: return t.ink
            }
        }()
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(t.hair)
                RoundedRectangle(cornerRadius: 1)
                    .fill(fill)
                    .frame(width: max(2, geo.size.width * pct))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 10) {
            PrimaryButton(label: isDecomposing
                ? (AIConfig.isConfigured ? "Mentor is mapping…" : "Mapping…")
                : "Decompose with mentor"
            ) {
                decompose()
            }
            .disabled(isDecomposing)

            PillButton(label: "Add checkpoint") {
                Haptics.light()
                addContext = AddContext(parent: nil, editing: nil)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No checkpoints yet.")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)
            Text("Let the mentor break this goal into a chain, or add the first checkpoint yourself.")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
        }
        .padding(.vertical, 8)
        .fadeSlideIn(delay: 0.1)
    }

    // MARK: - Decompose

    /// Generates a checkpoint chain. Tries `AIService.decomposeGoalJSON`; on any
    /// failure (offline, parse failure, empty) falls back to the deterministic
    /// `MilestoneGenerator.defaultChain` skeleton.
    private func decompose() {
        guard !isDecomposing else { return }
        isDecomposing = true
        Task { @MainActor in
            defer { isDecomposing = false }

            if AIConfig.isConfigured || SupabaseService.shared.isAuthenticated {
                if let drafts = try? await aiDrafts(), !drafts.isEmpty {
                    MilestoneGenerator.materialize(drafts, for: goal, context: modelContext)
                    finishDecompose()
                    return
                }
            }

            // Offline / failure fallback: deterministic skeleton.
            let drafts = MilestoneGenerator.defaultChain(for: goal)
            MilestoneGenerator.materialize(drafts, for: goal, context: modelContext)
            finishDecompose()
        }
    }

    private func finishDecompose() {
        // Refresh status across the freshly created chain.
        for milestone in goal.milestones {
            MilestoneProgressService.refreshStatus(of: milestone)
        }
        try? modelContext.save()
        Haptics.medium()
    }

    /// Calls the AI and parses the JSON array into `MilestoneDraft`s, resolving
    /// `parent_index` into draft indices and `weeks_from_now_*` into windows.
    private func aiDrafts() async throws -> [MilestoneDraft] {
        let jsonText = try await AIService.decomposeGoalJSON(goal: goal, horizon: goal.horizon)
        guard let data = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let now = Date.now
        let calendar = Calendar.current
        var drafts: [MilestoneDraft] = []

        for (offset, dict) in items.enumerated() {
            guard let rawTitle = dict["title"] as? String,
                  !rawTitle.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let period = MilestonePeriod(rawValue: (dict["period"] as? String ?? "").lowercased()) ?? .month

            // Window from week offsets; guard against inverted / missing values.
            let startWeeks = (dict["weeks_from_now_start"] as? Int)
                ?? (dict["weeks_from_now_start"] as? Double).map { Int($0) }
                ?? 0
            let endWeeksRaw = (dict["weeks_from_now_end"] as? Int)
                ?? (dict["weeks_from_now_end"] as? Double).map { Int($0) }
                ?? (startWeeks + max(period.approximateDays / 7, 1))
            let endWeeks = max(endWeeksRaw, startWeeks + 1)

            let start = calendar.date(byAdding: .weekOfYear, value: startWeeks, to: now) ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: endWeeks, to: now)
                ?? start.addingTimeInterval(Double(period.approximateDays) * 86_400)

            // parent_index must reference an EARLIER item.
            var parentIndex: Int? = nil
            if let pi = dict["parent_index"] as? Int, pi >= 0, pi < offset {
                parentIndex = pi
            } else if let pid = dict["parent_index"] as? Double {
                let pi = Int(pid)
                if pi >= 0, pi < offset { parentIndex = pi }
            }

            let target: Double? = {
                if let d = dict["target_value"] as? Double { return d }
                if let i = dict["target_value"] as? Int { return Double(i) }
                return nil
            }()
            let unit = (dict["unit"] as? String) ?? goal.unit

            drafts.append(MilestoneDraft(
                title: rawTitle.trimmingCharacters(in: .whitespaces),
                detail: (dict["detail"] as? String) ?? "",
                period: period,
                parentIndex: parentIndex,
                startDate: start,
                endDate: end,
                targetValue: target,
                unit: unit,
                sortIndex: offset
            ))
        }
        return drafts
    }

    // MARK: - Helpers

    /// Coarse→fine ordering rank for a period (year=0 … week=3). Drives both the
    /// band sort and the row indentation depth.
    private func periodRank(_ period: MilestonePeriod) -> Int {
        switch period {
        case .year: return 0
        case .quarter: return 1
        case .month: return 2
        case .week: return 3
        }
    }
}
