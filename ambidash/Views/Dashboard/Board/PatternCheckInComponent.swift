import SwiftUI
import SwiftData

/// PATTERN CHECK-INS (build-order #8) — the gentle, on-device "offers not verdicts"
/// surface from /tmp/v3-design/differentiators.md.
///
/// Reads the user's PRIVATE logged actuals + energy check-ins (via
/// `LearningService.buildProfile`), asks `PatternCheckInService` for a PERSISTENT
/// drift worth surfacing (real wake/sleep vs plan, low-adherence windows, consistent
/// duration deltas), and shows ONE soft check-in card at a time:
///
///   "You've been waking ~8:30 · from 6 days of data
///    [ Move wake to 08:30 ]  [ Keep 07:00, nudge the night ]"
///
/// Accepting the primary choice EDITS `UserPreferences` (the only mutation) and saves;
/// the secondary keeps the target. Either way the offer is dismissed for the session.
/// NON-PUNITIVE by construction: no red, no failure language, the `deferred` token for
/// any de-emphasis, confidence always shown, and "not now" is a single tap.
///
/// Owns small `@Query`s for the recent actuals/check-ins (inherently changing as the
/// day is logged), like EnergyCheckinComponent — so it is intentionally NOT fed from
/// the static BoardData snapshot. iOS-only (lives under Views/, excluded from the mac
/// target); the underlying service is shared.
struct PatternCheckInComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    let boardData: BoardData

    /// Recent logged actuals (the learning window). Newest first; filtered to the last
    /// ~14 days at compute time so a stale month can't skew a "this week" pattern.
    @Query(sort: \ActualEvent.date, order: .reverse) private var actuals: [ActualEvent]
    @Query(sort: \EnergyCheckin.date, order: .reverse) private var checkins: [EnergyCheckin]

    /// The single offer currently shown, or nil when nothing crosses its confidence
    /// gate (the quiet, common case → the card renders nothing).
    @State private var insight: PatternCheckInService.PatternInsight?
    /// AI-warmed body line; starts as the deterministic copy so the card is never blank.
    @State private var warmedBody: String = ""
    /// Kinds the user dismissed/answered this session, so we don't immediately re-offer.
    @State private var resolvedKinds: Set<PatternCheckInService.Kind> = []
    /// A brief calm acknowledgement after a choice ("Updated — your mornings now start
    /// at 8:30"), shown in place of the card before it clears.
    @State private var acknowledgement: String?

    private let window = 14

    var body: some View {
        let t = tm.resolved
        Group {
            if let ack = acknowledgement {
                acknowledgementCard(ack, t)
            } else if let insight {
                card(insight, t)
            } else {
                // Nothing to surface — render an empty, zero-height view so the card
                // takes no space on the board when there's no gentle pattern.
                Color.clear.frame(height: 0)
            }
        }
        .animation(MotionPreference.animation(.ambidashSpring), value: insight?.id)
        .animation(MotionPreference.animation(.ambidashSpring), value: acknowledgement)
        .task(id: dataFingerprint) { await recompute() }
    }

    // MARK: - The offer card

    @ViewBuilder
    private func card(_ insight: PatternCheckInService.PatternInsight, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: t.space.component) {
            header(insight, t)

            Text(warmedBody.isEmpty ? insight.body : warmedBody)
                .font(t.body(13))
                .foregroundStyle(t.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(insight.confidence)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.faint)

            choiceRow(insight, t)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gentle check-in: \(insight.title)")
    }

    @ViewBuilder
    private func header(_ insight: PatternCheckInService.PatternInsight, _ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol(for: insight.kind))
                .font(.system(size: 12))
                .foregroundStyle(t.accent)
            Text(insight.title)
                .font(t.body(13))
                .fontWeight(.semibold)
                .foregroundStyle(t.ink)
            Spacer(minLength: 4)
            // A quiet "not now" — dismiss without answering; comes back another day.
            Button {
                Haptics.light()
                dismissCurrent()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(t.faint)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not now")
        }
    }

    @ViewBuilder
    private func choiceRow(_ insight: PatternCheckInService.PatternInsight, _ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            ForEach(insight.choices) { choice in
                Button {
                    accept(choice, in: insight)
                } label: {
                    Text(choice.label)
                        .font(.system(size: 12, weight: choice.isPrimary ? .semibold : .regular))
                        .foregroundStyle(choice.isPrimary ? t.ink : t.deferred)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(choice.isPrimary ? t.accentSoft : t.sunken.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(choice.isPrimary ? t.accent.opacity(0.5) : t.hair.opacity(0.6),
                                        lineWidth: choice.isPrimary ? 1 : 0.5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .accessibilityLabel(choice.label)
            }
        }
    }

    // MARK: - Acknowledgement (post-accept)

    @ViewBuilder
    private func acknowledgementCard(_ text: String, _ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(t.accent)
            Text(text)
                .font(t.body(12))
                .foregroundStyle(t.muted)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: - Actions

    /// Accept a choice: edit UserPreferences (when the choice mutates), save, show a
    /// brief acknowledgement, then clear. Routes ALL edits through
    /// `PatternCheckInService.apply` so the card never duplicates preference logic.
    private func accept(_ choice: PatternCheckInService.Choice, in insight: PatternCheckInService.PatternInsight) {
        Haptics.success()
        resolvedKinds.insert(insight.kind)

        if let prefs = boardData.profile?.userPreferences {
            let changed = PatternCheckInService.apply(choice, to: prefs)
            if changed { try? modelContext.save() }
            acknowledgement = changed
                ? "Updated — your plan now matches how your days actually go."
                : "Got it. Nothing changed; you're in control."
        } else {
            acknowledgement = "Got it."
        }

        self.insight = nil
        // Clear the acknowledgement after a calm beat so the card frees its space.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(MotionPreference.animation(.ambidashSpring)) { acknowledgement = nil }
        }
    }

    /// "Not now" — dismiss without answering. Suppress this kind for the session so it
    /// doesn't re-appear on the next recompute, but it can resurface another day.
    private func dismissCurrent() {
        if let kind = insight?.kind { resolvedKinds.insert(kind) }
        withAnimation(MotionPreference.animation(.ambidashSpring)) { insight = nil }
    }

    // MARK: - Compute

    /// A cheap fingerprint that changes when the underlying data changes, so the
    /// `.task(id:)` re-derives the offer without polling. Counts + newest dates only.
    private var dataFingerprint: String {
        "\(actuals.count)-\(checkins.count)-\(actuals.first?.date.timeIntervalSince1970 ?? 0)"
    }

    /// Build the LearnedProfile from the recent window, ask the service for the top
    /// offer (excluding kinds already resolved this session), then warm its body line.
    private func recompute() async {
        guard let prefs = boardData.profile?.userPreferences else {
            insight = nil; return
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now)
            ?? Date.now.addingTimeInterval(-Double(window) * 86_400)
        let recentActuals = actuals.filter { $0.date >= cutoff }
        let recentCheckins = checkins.filter { $0.date >= cutoff }

        let profile = LearningService.buildProfile(actuals: recentActuals, checkins: recentCheckins)
        let titles = goalTitleMap()
        let candidates = PatternCheckInService.insights(
            profile: profile, prefs: prefs, goalTitles: titles
        )
        let top = candidates.first(where: { !resolvedKinds.contains($0.kind) })

        guard let top else {
            insight = nil; warmedBody = ""; return
        }
        // Show immediately with deterministic copy; warm asynchronously.
        insight = top
        warmedBody = top.body
        let warmed = await PatternCheckInPhrasing.body(for: top)
        // Only apply if the same offer is still showing (the user may have acted).
        if insight?.id == top.id { warmedBody = warmed }
    }

    private func goalTitleMap() -> [UUID: String] {
        var map: [UUID: String] = [:]
        for g in boardData.activeGoals { map[g.id] = g.title }
        return map
    }

    // MARK: - Glyphs

    private func symbol(for kind: PatternCheckInService.Kind) -> String {
        switch kind {
        case .wake:         return "sunrise"
        case .sleep:        return "moon.stars"
        case .duration:     return "timer"
        case .adherence:    return "calendar.badge.exclamationmark"
        case .energyTrough: return "bolt.slash"
        }
    }
}
