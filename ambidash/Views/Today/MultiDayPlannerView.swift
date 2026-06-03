import SwiftUI
import SwiftData

/// v4 #4 + #6 — the multi-day planner. A customizable 1–7 day look-ahead where you
/// can move tasks between days and see the soonest big commitment up top
/// ("Midterm in 2 days"). Presented as a sheet from Today. The window is anchored on
/// day 0 = today; moving tasks is the manual "shift the days around" gesture.
struct MultiDayPlannerView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \DailyPlan.date) private var plans: [DailyPlan]
    @Query(filter: #Predicate<Milestone> { $0.completedAt == nil }, sort: \Milestone.endDate)
    private var openMilestones: [Milestone]

    /// Persisted day-count (1…7), shared with the dashboard Week Ahead card.
    @AppStorage("multiday_count") private var dayCount = 3

    var body: some View {
        let t = tm.resolved
        let days = MultiDayPlannerService.days(from: .now, count: dayCount)
        let bigEvent = MultiDayPlannerService.soonestBigEvent(milestones: openMilestones)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: t.space.section) {
                    dayCountControl(t)
                    if let bigEvent { bigEventBanner(bigEvent, t) }
                    ForEach(Array(days.enumerated()), id: \.offset) { offset, day in
                        dayColumn(offset: offset, day: day, allDays: days, t: t)
                    }
                }
                .padding(20)
            }
            .background(t.bg)
            .navigationTitle("Plan Ahead")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("planAhead.sheet")
    }

    // MARK: - Day-count control

    @ViewBuilder
    private func dayCountControl(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: t.space.tight) {
            SectionLabel(title: "Days to show")
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { n in
                    Button {
                        Haptics.selection()
                        dayCount = n
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 15, weight: dayCount == n ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(dayCount == n ? t.bg : t.muted)
                            .frame(width: 34, height: 34)
                            .background(dayCount == n ? t.accent : t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(t.hair, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planAhead.dayCount.\(n)")
                }
            }
        }
    }

    // MARK: - Big event banner

    @ViewBuilder
    private func bigEventBanner(_ event: BigEventCountdown, _ t: ResolvedTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundStyle(t.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(t.heading(17))
                    .foregroundStyle(t.ink)
                    .lineLimit(1)
                Text(event.phrase.capitalizedFirst)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(t.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("planAhead.bigEvent")
    }

    // MARK: - Day column

    @ViewBuilder
    private func dayColumn(offset: Int, day: Date, allDays: [Date], t: ResolvedTheme) -> some View {
        let cal = Calendar.current
        let dayPlan = plans.first { cal.isDate($0.date, inSameDayAs: day) }
        let actions = (dayPlan?.actions ?? []).sorted { $0.timeSlot < $1.timeSlot }

        VStack(alignment: .leading, spacing: t.space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(label(offset: offset, day: day))
                    .font(.system(size: 12, weight: offset == 0 ? .semibold : .regular, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(offset == 0 ? t.accent : t.muted)
                Spacer()
                if !actions.isEmpty {
                    Text("\(actions.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }

            if actions.isEmpty {
                Text("Nothing planned")
                    .font(t.body(13))
                    .foregroundStyle(t.faint)
                    .padding(.vertical, 6)
            } else {
                ForEach(actions) { action in
                    taskRow(action, currentDay: day, allDays: allDays, t: t)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
        .accessibilityIdentifier("planAhead.day.\(offset)")
    }

    @ViewBuilder
    private func taskRow(_ action: PlannedAction, currentDay: Date, allDays: [Date], t: ResolvedTheme) -> some View {
        let cal = Calendar.current
        HStack(spacing: 10) {
            if !action.timeSlot.isEmpty {
                Text(action.timeSlot)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .frame(width: 42, alignment: .leading)
            }
            Text(action.title)
                .font(t.body(14))
                .foregroundStyle(t.ink)
                .strikethrough(action.lifecycle == .done, color: t.faint)
                .lineLimit(1)
            Spacer(minLength: 0)

            Menu {
                ForEach(Array(allDays.enumerated()), id: \.offset) { idx, target in
                    if !cal.isDate(target, inSameDayAs: currentDay) {
                        Button {
                            Haptics.light()
                            MultiDayPlannerService.move(action, to: target, in: plans, context: modelContext)
                            try? modelContext.save()
                        } label: {
                            Label("Move to \(label(offset: idx, day: target))", systemImage: "arrow.right")
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13))
                    .foregroundStyle(t.muted)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("planAhead.move")
        }
        .padding(.vertical, 4)
    }

    private func label(offset: Int, day: Date) -> String {
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return day.formatted(.dateTime.weekday(.wide).day())
        }
    }
}

private extension String {
    /// Uppercases just the first character ("in 2 days" → "In 2 days").
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

private extension View {
    @ViewBuilder func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
