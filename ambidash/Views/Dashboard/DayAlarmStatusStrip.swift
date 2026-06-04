// ambidash/Views/Dashboard/DayAlarmStatusStrip.swift
//
// v5 feat/v5-alarm-connect — the dashboard's at-a-glance day-alarm status. A compact, calm
// strip that shows the user's live recurring wake/bedtime alarms (time + style). Renders
// NOTHING when no day alarm is enabled, so it never adds clutter for users who don't use it.
import SwiftUI

struct DayAlarmStatusStrip: View {
    @Environment(ThemeManager.self) private var tm

    /// The live preferences (alarm enablement + times). Nil before any prefs exist.
    let prefs: UserPreferences?
    /// The day's first scheduled block minute-of-day, when plan-sync is on. Nil = use the
    /// static wake time.
    let planWakeMinutes: Int?

    private var statuses: [AlarmService.DayAlarmDirective] {
        guard let prefs else { return [] }
        return AlarmService.dayAlarmStatuses(
            wakeEnabled: prefs.wakeAlarmEnabled, wakeModeRaw: prefs.wakeAlarmModeRaw, wakeClock: prefs.wakeTime,
            bedtimeEnabled: prefs.bedtimeAlarmEnabled, bedtimeModeRaw: prefs.bedtimeAlarmModeRaw, bedtimeClock: prefs.sleepTime,
            syncWakeToPlan: prefs.syncWakeAlarmToPlan, planWakeMinutes: planWakeMinutes
        )
    }

    var body: some View {
        let t = tm.resolved
        if !statuses.isEmpty {
            HStack(spacing: 10) {
                ForEach(statuses, id: \.kind) { status in
                    pill(for: status, t: t)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    @ViewBuilder
    private func pill(for status: AlarmService.DayAlarmDirective, t: ResolvedTheme) -> some View {
        HStack(spacing: 6) {
            Image(systemName: glyph(for: status))
                .font(.system(size: 11))
                .foregroundStyle(t.muted)
            Text(status.clock)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(t.ink)
            Text(label(for: status.kind))
                .font(.system(size: 10, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(t.muted)
            if status.syncedToPlan {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                    .foregroundStyle(t.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(t.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(t.hair, lineWidth: 0.5))
    }

    /// Sunrise/moon for the kind, swapped to a louder glyph when it's an unmissable alarm.
    private func glyph(for status: AlarmService.DayAlarmDirective) -> String {
        switch status.kind {
        case .wake:    return status.mode == .alarm ? "alarm.fill" : "sunrise"
        case .bedtime: return status.mode == .alarm ? "alarm.fill" : "moon.stars"
        }
    }

    private func label(for kind: AlarmService.DayAlarmKind) -> String {
        switch kind {
        case .wake:    return "WAKE"
        case .bedtime: return "BED"
        }
    }

    private var accessibilityLabel: String {
        let parts = statuses.map { status -> String in
            let kindWord = status.kind == .wake ? "Wake alarm" : "Bedtime reminder"
            let synced = status.syncedToPlan ? ", synced to today's plan" : ""
            return "\(kindWord) at \(status.clock)\(synced)"
        }
        return parts.joined(separator: ". ")
    }
}
