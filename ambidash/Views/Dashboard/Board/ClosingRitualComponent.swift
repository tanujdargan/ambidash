import SwiftUI
import SwiftData

/// CLOSING RITUAL — the dashboard entry point to the gentle end-of-day flow. A
/// calm card that, in the evening, invites the user to "close the day": celebrate
/// what they did, jot one line, and pick tomorrow's ONE thing. Tapping opens
/// `ClosingRitualSheet`.
///
/// Non-punitive: the card never shows a completion %, never nags, and gives a warm
/// preview of how many things were done today (partials included) framed as
/// accomplishment — never a remaining/overdue count.
///
/// Owns small `@Query`s for today's plan / actuals / reflection so its preview
/// reflects live state; it is intentionally NOT fed from the static BoardData
/// snapshot (like EnergyCheckin / CaptureInbox).
struct ClosingRitualComponent: View {
    @Environment(ThemeManager.self) private var tm

    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \ActualEvent.date, order: .reverse) private var allActuals: [ActualEvent]

    @State private var showRitual = false

    private var calendar: Calendar { .current }

    private var todayPlan: DailyPlan? {
        plans.first { calendar.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayReflection: Reflection? {
        reflections.first { calendar.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayActuals: [ActualEvent] {
        allActuals.filter { calendar.isDate($0.date, inSameDayAs: .now) }
    }

    private var recap: ClosingRitualService.Recap {
        ClosingRitualService.recap(plan: todayPlan, actuals: todayActuals, day: .now, calendar: calendar)
    }

    /// True once the user has set a tomorrow's-one-thing today — the card reflects
    /// that the ritual is complete (calmly, never a checkmark-pressure badge).
    private var ritualDone: Bool {
        !(todayReflection?.tomorrowOneThing.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    var body: some View {
        let t = tm.resolved
        let r = recap
        Button {
            showRitual = true
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: t.space.component) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(title: "Close the day")
                    Spacer()
                    Image(systemName: ritualDone ? "moon.stars.fill" : "moon.stars")
                        .font(.system(size: 13))
                        .foregroundStyle(t.accent)
                }

                Text(headline(r))
                    .font(t.heading(16))
                    .foregroundStyle(t.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(ritualDone ? "Tomorrow's one thing is set — tap to review."
                                    : "Celebrate today and pick tomorrow's one thing.")
                        .font(t.body(11))
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
        .sheet(isPresented: $showRitual) {
            ClosingRitualSheet()
                .environment(tm)
        }
        .accessibilityLabel("Close the day — \(headline(r))")
    }

    private func headline(_ r: ClosingRitualService.Recap) -> String {
        let n = r.done.count
        if n == 0 {
            return r.restCount > 0 ? "A quieter day — that counts too." : "Wrap up tonight, gently."
        }
        return "You did \(n) \(n == 1 ? "thing" : "things") today."
    }
}
