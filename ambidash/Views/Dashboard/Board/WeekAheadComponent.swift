import SwiftUI
import SwiftData

/// v4: a 1–7 day look-ahead so dated commitments are VISIBLE before they arrive
/// ("midterm in 2 days"). Shows the next 7 days as rows; each day surfaces the
/// open milestone deadlines (Milestone.endDate) that land on it. Owns a small
/// @Query for milestones (they aren't in the shared BoardData); the date-window
/// filtering happens in Swift to avoid #Predicate date-math limits.
struct WeekAheadComponent: View {
    @Environment(ThemeManager.self) private var tm

    /// Open (incomplete) milestones, soonest deadline first. Windowed to the next
    /// 7 days in `body` — a #Predicate can't reference `.now` cleanly.
    @Query(filter: #Predicate<Milestone> { $0.completedAt == nil }, sort: \Milestone.endDate)
    private var openMilestones: [Milestone]

    private let dayCount = 7

    var body: some View {
        let t = tm.resolved
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<dayCount).compactMap { cal.date(byAdding: .day, value: $0, to: today) }

        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Week Ahead")

            VStack(spacing: t.space.tight) {
                ForEach(Array(days.enumerated()), id: \.offset) { offset, day in
                    let deadlines = openMilestones.filter { cal.isDate($0.endDate, inSameDayAs: day) }
                    dayRow(offset: offset, day: day, deadlines: deadlines, t: t)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        // .contain keeps the per-day text accessible while making the container
        // itself queryable by XCUITest via the identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("component.weekAhead")
    }

    @ViewBuilder
    private func dayRow(offset: Int, day: Date, deadlines: [Milestone], t: ResolvedTheme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Relative day label — Today / Tomorrow / weekday.
            Text(label(offset: offset, day: day))
                .font(.system(size: 11, weight: offset == 0 ? .semibold : .regular, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(offset == 0 ? t.accent : t.muted)
                .frame(width: 72, alignment: .leading)

            if deadlines.isEmpty {
                Text("—")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(deadlines.prefix(3)) { m in
                        HStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(t.accent)
                            Text(m.title)
                                .font(t.body(13))
                                .foregroundStyle(t.ink)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func label(offset: Int, day: Date) -> String {
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return day.formatted(.dateTime.weekday(.abbreviated).day())
        }
    }
}
