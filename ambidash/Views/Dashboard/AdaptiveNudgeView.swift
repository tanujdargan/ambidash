// ambidash/Views/Dashboard/AdaptiveNudgeView.swift
//
// v5 feat/v5-adaptive-scheduling — the dashboard's single, gentle "let's adjust today" nudge. It
// surfaces the most relevant empathetic suggestion (a rough night → lighter day; blocks that
// slipped → reschedule; yesterday's unfinished → still important or let go) one at a time, and
// performs only safe, reversible actions. Renders nothing when the day's on track or once
// dismissed for the session.
import SwiftUI
import SwiftData

struct AdaptiveNudgeView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    /// Dismissed suggestion kinds (by rawValue) for this session, so a tapped/declined nudge
    /// doesn't immediately reappear.
    @State private var dismissed: Set<String> = []

    private var prefs: UserPreferences? { profiles.first?.userPreferences }

    private var todayPlan: DailyPlan? { plans.first { Calendar.current.isDateInToday($0.date) } }
    private var yesterdayPlan: DailyPlan? {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: .now) else { return nil }
        return plans.first { cal.isDate($0.date, inSameDayAs: yesterday) }
    }
    private var todaySleepHours: Double {
        guard let snap = snapshots.first, Calendar.current.isDateInToday(snap.date) else { return 0 }
        return snap.sleepHours
    }

    /// The top suggestion to surface, by priority: health > missed-today > carry-forward.
    private var suggestion: AdaptiveSuggestion? {
        let candidates: [AdaptiveSuggestion?] = [
            healthSuggestion,
            missedSuggestion,
            carrySuggestion,
        ]
        return candidates.compactMap { $0 }.first { !dismissed.contains($0.id) }
    }

    private var healthSuggestion: AdaptiveSuggestion? {
        // Don't offer to lighten a day already marked hard.
        guard !(HardModeService.isHardToday(prefs)) else { return nil }
        let blocks = (todayPlan?.actions ?? []).filter { $0.anchorKind == .goalWork }.count
        return DisruptionService.healthLightenSuggestion(sleepHours: todaySleepHours, plannedGoalBlocks: blocks)
    }

    private var missedSuggestion: AdaptiveSuggestion? {
        let missed = missedTodayItems
        guard !missed.isEmpty else { return nil }
        return DisruptionService.rescheduleMissedSuggestion(missed: missed, freeSlots: [])
    }

    private var carrySuggestion: AdaptiveSuggestion? {
        DisruptionService.carryForwardSuggestion(unfinished: carryItems)
    }

    var body: some View {
        let t = tm.resolved
        if let s = suggestion {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: s.symbol).font(.system(size: 18)).foregroundStyle(t.accent).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.title).font(t.heading(15)).foregroundStyle(t.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(s.body).font(t.body(13)).foregroundStyle(t.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    ForEach(s.options) { option in
                        Button {
                            handle(option, for: s)
                        } label: {
                            Text(option.label)
                                .font(.system(size: 13, weight: option.isPrimary ? .semibold : .regular))
                                .foregroundStyle(option.isPrimary ? t.bg : t.ink)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(option.isPrimary ? t.accent : t.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(option.isPrimary ? Color.clear : t.hair, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
            .accessibilityIdentifier("adaptive.nudge")
        }
    }

    // MARK: - Data

    private var missedTodayItems: [DisruptionService.MissedItem] {
        guard let plan = todayPlan else { return [] }
        let nowMin = DisruptionService.nowMinutes(.now)
        return (plan.actions ?? [])
            .filter { $0.anchorKind == .goalWork && !DisruptionService.isSettled($0) }
            .filter { (DailyTimeline.minutes(from: $0.timeSlot) ?? .max) < nowMin }
            .map { .init(title: $0.title, originalSlot: $0.timeSlot) }
    }

    private var carryItems: [DisruptionService.CarryItem] {
        guard let plan = yesterdayPlan else { return [] }
        return (plan.actions ?? [])
            .filter { $0.anchorKind == .goalWork && !DisruptionService.isSettled($0) }
            .map { .init(title: $0.title, goalTitle: $0.goalTitleSnapshot) }
    }

    // MARK: - Actions (safe + reversible)

    private func handle(_ option: AdaptiveOption, for suggestion: AdaptiveSuggestion) {
        Haptics.light()
        switch (suggestion.kind, option.id) {
        case (.healthLighten, "lighten"):
            if let prefs { HardModeService.markHard(prefs); try? modelContext.save() }
        case (.carryForward, "letgo"):
            // Gently let yesterday's unfinished goal-work go — settled as "let go", not failed,
            // so CarryOverService stops re-carrying it.
            for action in (yesterdayPlan?.actions ?? []) where action.anchorKind == .goalWork && !DisruptionService.isSettled(action) {
                action.applyLifecycle(.abandoned)
            }
            try? modelContext.save()
        default:
            // The other choices (keep my plan / reschedule / roll forward) acknowledge and dismiss;
            // the existing carry-forward + re-plan flows handle the actual movement.
            break
        }
        dismissed.insert(suggestion.id)
    }
}
