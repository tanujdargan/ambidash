import SwiftUI
import SwiftData

/// WINS WALL — a calm card of EVIDENCE: "look what you did". Shows the top few recent
/// wins (completed/partial `ActualEvent`s + lifecycle `.done`/`.partial`
/// `PlannedAction`s, derived via `WinsService`) and a warm "X this week" count.
/// Partials COUNT and are shown as real progress — this surface is NEVER a deficit, a
/// completion %, or a count of misses.
///
/// Tapping opens `WinsWeekSheet`, the gentle "your week in wins" review (the week's
/// wins grouped by day). Reuses the same dedup-by-`linkedActionID` logic as the closing
/// ritual via the shared `WinsService`, so a logged block is never celebrated twice.
///
/// Owns small read-only `@Query`s for recent actuals + plans (no mutation), so it is
/// intentionally NOT fed from the static BoardData snapshot.
struct WinsWallComponent: View {
    @Environment(ThemeManager.self) private var tm

    @Query(sort: \ActualEvent.date, order: .reverse) private var allActuals: [ActualEvent]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    @State private var showWeek = false

    private var calendar: Calendar { .current }

    /// 7-day rolling window ending today.
    private var weekInterval: DateInterval {
        WinsService.recentInterval(days: 7, calendar: calendar)
    }

    private var weekWins: [WinsService.WinItem] {
        WinsService.wins(in: weekInterval, actuals: allActuals, plans: plans, calendar: calendar)
    }

    /// Top recent wins for the compact preview.
    private var previewWins: [WinsService.WinItem] {
        Array(weekWins.prefix(3))
    }

    var body: some View {
        let t = tm.resolved
        let wins = weekWins
        Button {
            showWeek = true
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: t.space.component) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(title: "Wins")
                    Spacer()
                    Image(systemName: "rosette")
                        .font(.system(size: 13))
                        .foregroundStyle(t.accent)
                }

                Text(WinsService.headline(count: wins.count, days: 7))
                    .font(t.heading(16))
                    .foregroundStyle(t.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if previewWins.isEmpty {
                    Text("Do one real thing today — partials count — and it shows up right here.")
                        .font(t.body(11))
                        .foregroundStyle(t.muted)
                } else {
                    VStack(alignment: .leading, spacing: t.space.tight) {
                        ForEach(previewWins) { item in
                            winRow(item, t)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text(wins.isEmpty ? "Open your week in wins" : "See your week in wins")
                        .font(.system(size: 11))
                        .foregroundStyle(t.muted)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(t.faint)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .leading) {
                t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
            }
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .sheet(isPresented: $showWeek) {
            WinsWeekSheet().environment(tm)
        }
        .accessibilityLabel("Wins — \(WinsService.headline(count: wins.count, days: 7))")
    }

    @ViewBuilder
    private func winRow(_ item: WinsService.WinItem, _ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.isPartial ? "circle.lefthalf.filled" : "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(t.accent)
            Text(item.title)
                .font(t.body(13))
                .foregroundStyle(t.ink2)
                .lineLimit(1)
            Spacer(minLength: 4)
            if item.isPartial {
                Text("partly")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }
}
