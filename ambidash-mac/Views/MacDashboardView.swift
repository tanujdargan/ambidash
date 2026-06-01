import SwiftUI
import SwiftData

/// Desktop dashboard: the composite (pulse) score with a real trailing
/// composite-history sparkline, per-dimension scores, the three most recently
/// touched goals, and the latest synced vitals from the most recent
/// IntegrationSnapshot. Clicking the composite or any dimension reveals a
/// score breakdown (the honest math, mirroring iOS' ScoreBreakdownCard).
///
/// All data is read live from the shared CloudKit-backed SwiftData store, so it
/// mirrors whatever the iOS app has synced.
struct MacDashboardView: View {
    @Environment(ThemeManager.self) private var tm
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \Goal.lastProgressDate, order: .reverse) private var recentGoals: [Goal]

    @State private var breakdownTarget: ScoreBreakdownTarget?

    private var latestSnapshot: IntegrationSnapshot? { snapshots.first }

    private var dimensionScores: [LifeDimension: Int] {
        DimensionScoreCalculator.scores(from: goals, snapshot: latestSnapshot)
    }

    private var pulse: Int {
        PulseScoreCalculator.pulse(from: dimensionScores)
    }

    private var sparkline: [Double] {
        CompositeHistoryCalculator.dailyComposite(from: goals, days: 14, todayComposite: pulse)
    }

    private var latestThree: [Goal] {
        Array(recentGoals.filter { $0.isActive }.prefix(3))
    }

    var body: some View {
        let theme = tm.resolved
        MacScreen("Dashboard", subtitle: "Your life pulse, synced from iCloud") {
            // Composite + active goals + on-track at a glance.
            HStack(spacing: 16) {
                Button { toggleBreakdown(.composite) } label: {
                    compositeBadge(theme)
                }
                .buttonStyle(.plain)
                MacScoreBadge(value: goals.count, caption: "Active Goals")
                MacScoreBadge(
                    value: goals.filter { $0.computedStatus == .onTrack }.count,
                    caption: "On Track",
                    tint: theme.ok
                )
            }

            if breakdownTarget == .composite {
                compositeBreakdown(theme)
            }

            // CAPTURE (design principle #4) — the universal dump + triage inbox, the
            // app's most-validated feature. Surfaced high so it's the first thing
            // reachable, mirroring its prominence on iOS.
            MacCaptureCard()

            // Per-dimension scores; click any row to reveal its breakdown.
            MacCard("Dimensions") {
                ForEach(LifeDimension.allCases, id: \.self) { dim in
                    let score = dimensionScores[dim] ?? 0
                    Button { toggleBreakdown(.dimension(dim)) } label: {
                        dimensionRow(dim, score: score, theme: theme)
                    }
                    .buttonStyle(.plain)

                    if breakdownTarget == .dimension(dim) {
                        dimensionBreakdown(dim, theme: theme)
                            .padding(.leading, 22)
                    }
                }
            }

            // Three most recently touched goals.
            MacCard("Latest Goals") {
                if latestThree.isEmpty {
                    Text("No goals yet. Add one in the Goals tab.")
                        .font(theme.body(14))
                        .foregroundStyle(theme.muted)
                } else {
                    ForEach(latestThree) { goal in
                        HStack(spacing: 12) {
                            Image(systemName: goal.domain.icon)
                                .foregroundStyle(AmbidashTheme.dimensionColor(for: goal.domain.dimension))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                                    .font(theme.body(14))
                                    .foregroundStyle(theme.ink)
                                Text(goal.computedStatus.label)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(goal.computedStatus.color)
                            }
                            Spacer()
                            if goal.hasTarget {
                                Text("\(Int(goal.percentComplete * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        if goal.id != latestThree.last?.id {
                            Divider().overlay(theme.hair)
                        }
                    }
                }
            }

            // Latest synced vitals.
            MacCard("Vitals") {
                if let snap = latestSnapshot {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        vital("Sleep", String(format: "%.1f h", snap.sleepHours))
                        vital("Steps", "\(snap.steps)")
                        vital("Workouts", "\(snap.workoutCount)")
                        vital("Screen", String(format: "%.1f h", snap.screenTimeHours))
                    }
                    Text("Last synced \(snap.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(theme.body(12))
                        .foregroundStyle(theme.faint)
                } else {
                    Text("No vitals yet. Open AmbiDash on iPhone to sync your health data via iCloud.")
                        .font(theme.body(14))
                        .foregroundStyle(theme.muted)
                }
            }
        }
    }

    // MARK: - Composite badge + sparkline

    @ViewBuilder
    private func compositeBadge(_ theme: ResolvedTheme) -> some View {
        VStack(spacing: 6) {
            Text("\(pulse)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
            Sparkline(values: sparkline, tint: theme.accent)
                .frame(height: 22)
                .padding(.horizontal, 6)
            Text("PULSE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.muted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(breakdownTarget == .composite ? theme.accent : .clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func compositeBreakdown(_ theme: ResolvedTheme) -> some View {
        MacCard("Composite Breakdown") {
            Text("The composite is the average of your six dimension scores.")
                .font(theme.body(12))
                .foregroundStyle(theme.muted)
            ForEach(LifeDimension.allCases, id: \.self) { dim in
                HStack {
                    Circle().fill(AmbidashTheme.dimensionColor(for: dim)).frame(width: 8, height: 8)
                    Text(dim.fullName).font(theme.body(13)).foregroundStyle(theme.ink)
                    Spacer()
                    Text("\(dimensionScores[dim] ?? 0)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.muted)
                }
            }
            Divider().overlay(theme.hair)
            HStack {
                Text("Average").font(theme.body(13).weight(.semibold)).foregroundStyle(theme.ink)
                Spacer()
                Text("\(pulse)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    // MARK: - Dimension row + breakdown

    @ViewBuilder
    private func dimensionRow(_ dim: LifeDimension, score: Int, theme: ResolvedTheme) -> some View {
        HStack {
            Circle()
                .fill(AmbidashTheme.dimensionColor(for: dim))
                .frame(width: 10, height: 10)
            Text(dim.fullName)
                .font(theme.body(14))
                .foregroundStyle(theme.ink)
            Spacer()
            ProgressView(value: Double(score), total: 100)
                .frame(width: 200)
                .tint(AmbidashTheme.dimensionColor(for: dim))
            Text("\(score)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.muted)
                .frame(width: 32, alignment: .trailing)
            Image(systemName: breakdownTarget == .dimension(dim) ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.faint)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func dimensionBreakdown(_ dim: LifeDimension, theme: ResolvedTheme) -> some View {
        let detail = ScoreBreakdown.detail(for: dim, goals: goals, snapshot: latestSnapshot)
        VStack(alignment: .leading, spacing: 6) {
            if detail.hasGoals {
                ForEach(detail.goalLines) { line in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.title.isEmpty ? "Untitled goal" : line.title)
                            .font(theme.body(12))
                            .foregroundStyle(theme.ink)
                        Text(line.explanation)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.muted)
                    }
                }
                Text("Base \(detail.baseScore) (average of \(detail.goalLines.count) goal\(detail.goalLines.count == 1 ? "" : "s"))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.faint)
            } else {
                Text("No goals in this dimension — defaults to a neutral 50.")
                    .font(theme.body(12))
                    .foregroundStyle(theme.muted)
            }
            if let adj = detail.adjustment {
                Text("\(adj.label): blended \(adj.beforeScore) → \(adj.afterScore)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.sunken))
    }

    private func toggleBreakdown(_ target: ScoreBreakdownTarget) {
        breakdownTarget = (breakdownTarget == target) ? nil : target
    }

    @ViewBuilder
    private func vital(_ label: String, _ value: String) -> some View {
        let theme = tm.resolved
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A lightweight composite-history sparkline drawn with a `Path`. macOS-native,
/// no iOS-only modifiers, no external charting dependency.
struct Sparkline: View {
    let values: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let last = pts.last {
                    Circle().fill(tint).frame(width: 4, height: 4).position(last)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 100
        let range = max(maxV - minV, 1)
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let norm = (v - minV) / range
            let y = size.height - CGFloat(norm) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
