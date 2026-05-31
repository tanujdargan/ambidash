import SwiftUI
import SwiftData

/// WINS WEEK — the gentle "your week in wins" review. A read-only celebration of the
/// last 7 days of EVIDENCE, grouped by day, framed entirely as accomplishment. Partials
/// count. There is no completion %, no miss-count, no overdue pile — just "look what you
/// did". Mirrors `ClosingRitualSheet`'s calm structure.
///
/// Derives everything from existing data via `WinsService` (recent `ActualEvent`s +
/// completed/partial `PlannedAction`s, deduped by `linkedActionID`) — no new @Model, no
/// CloudKit migration. Owns its own read-only `@Query`s; it never mutates the store.
///
/// Reached by tapping the Wins Wall card, and also surfaced gently by the already-
/// present weekly-review notification (`NotificationService.scheduleWeeklyReview`).
struct WinsWeekSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var tm

    @Query(sort: \ActualEvent.date, order: .reverse) private var allActuals: [ActualEvent]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    private var calendar: Calendar { .current }

    private var interval: DateInterval {
        WinsService.recentInterval(days: 7, calendar: calendar)
    }

    private var wins: [WinsService.WinItem] {
        WinsService.wins(in: interval, actuals: allActuals, plans: plans, calendar: calendar)
    }

    private var days: [WinsService.DayWins] {
        WinsService.grouped(wins, calendar: calendar)
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header(t)
                        if days.isEmpty {
                            emptyState(t)
                        } else {
                            ForEach(days) { day in
                                daySection(day, t)
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Your week in wins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(t.accent)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST 7 DAYS")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(t.muted)
            Text(WinsService.headline(count: wins.count, days: 7))
                .font(.system(size: 24, weight: tm.typography.serifWeight, design: .serif))
                .tracking(-0.3)
                .lineSpacing(2)
                .foregroundStyle(t.ink)
        }
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your wins will gather here as the week goes on.")
                .font(.system(size: 14))
                .foregroundStyle(t.ink2)
            Text("Anything you do — fully or partly — counts. There's no minimum.")
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func daySection(_ day: WinsService.DayWins, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title: dayLabel(day.day))
                Spacer()
                Text("\(day.wins.count) \(day.wins.count == 1 ? "win" : "wins")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(day.wins) { item in
                    winRow(item, t)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func winRow(_ item: WinsService.WinItem, _ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.isPartial ? "circle.lefthalf.filled" : "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(t.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(t.ink)
                    .lineLimit(2)
                if item.isPartial {
                    Text("partly — and that counts")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
            Spacer(minLength: 4)
            if !item.clock.isEmpty {
                Text(item.clock)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
