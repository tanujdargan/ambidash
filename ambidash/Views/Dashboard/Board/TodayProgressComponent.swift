import SwiftUI

/// v4: a dedicated COMPLETION + PROGRESS surface — the "dopamine hit" of seeing
/// how many of today's blocks you've finished. Reads today's plan from the shared
/// `BoardData` (no per-component @Query) and counts `.done` lifecycle blocks.
/// Non-punitive by construction: an unfinished day is framed as momentum, never
/// failure; zero-done is an invitation, a full day is a celebration.
struct TodayProgressComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    private var actions: [PlannedAction] { boardData.todayPlan?.actions ?? [] }
    private var doneCount: Int { actions.filter { $0.lifecycle == .done }.count }
    private var total: Int { actions.count }
    private var fraction: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }

    /// Non-punitive encouragement keyed to progress — never shaming.
    private var message: String {
        if fraction >= 1 { return "Every block done — that's a full day." }
        if doneCount == 0 { return "Mark one done to get rolling." }
        return "Nice momentum — keep going."
    }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Today's Progress")

            if total == 0 {
                Text("No plan yet — your completed blocks will tally here.")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
            } else {
                HStack(spacing: 18) {
                    progressRing(t)
                    VStack(alignment: .leading, spacing: 4) {
                        // The headline count: the satisfying "X of Y done".
                        Text("\(doneCount) of \(total) done")
                            .font(t.heading(20))
                            .foregroundStyle(t.ink)
                        Text(message)
                            .font(t.body(12))
                            .foregroundStyle(fraction >= 1 ? t.accent : t.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("component.todayProgress")
        .accessibilityLabel("Today's progress: \(doneCount) of \(total) blocks done")
    }

    @ViewBuilder
    private func progressRing(_ t: ResolvedTheme) -> some View {
        ZStack {
            Circle().stroke(t.hair, lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(t.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(MotionPreference.animation(.ambidashSnap), value: fraction)
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(t.ink)
        }
        .frame(width: 58, height: 58)
    }
}
