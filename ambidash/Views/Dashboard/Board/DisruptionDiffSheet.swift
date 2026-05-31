import SwiftUI
import SwiftData

/// MID-DAY DISRUPTION MODE — the v3 differentiator (#1). Presents the proposed
/// re-plan as a DIFF over today's remaining plan: what is KEPT, MOVED, and gently
/// DROPPED (deferred — never red, never abandoned), with the ONE most-important thing
/// explicitly protected and a calm WHY on every line.
///
/// The user can:
///   • ACCEPT  → persist the diff (moved = new timeSlot; dropped = .deferred so it
///               rolls forward via CarryOverService). Snapshotted first, so it's
///               fully reversible.
///   • EDIT    → toggle any non-protected entry between keep / move / drop before
///               applying. The protected block can't be dropped.
///   • DECLINE → discard. Nothing was mutated, so this is a pure dismiss.
///   • TRIAGE  → "Just one thing" collapses the view to the single protected step.
///
/// Reads goals + prefs from the injected BoardData; owns the modelContext only to
/// persist on ACCEPT. The diff is an in-memory VALUE type (no @Model, no CloudKit
/// change). AI warms the top-line rationale (on-device → BYOK → canned); the
/// deterministic copy ships immediately so the sheet is never blank.
struct DisruptionDiffSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    let plan: DailyPlan
    let goals: [Goal]
    let prefs: UserPreferences?
    let trigger: DisruptionService.Trigger
    /// Called after a successful ACCEPT so the host can refresh/snapshot.
    var onApplied: () -> Void = {}

    /// The proposed diff (mutable so EDIT can flip entries). Built once on appear.
    @State private var diff: DisruptionService.PlanDiff?
    /// AI-warmed top-line rationale; starts as the deterministic copy.
    @State private var warmedRationale: String = ""
    /// Triage / "one thing now" — collapses to the single protected step.
    @State private var triageMode = false
    @State private var isEditing = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                if let diff {
                    content(diff, t)
                } else {
                    ProgressView().tint(t.accent)
                }
            }
            .navigationTitle(triageMode ? "One thing now" : "Re-plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { Haptics.light(); dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await buildAndWarm() }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ diff: DisruptionService.PlanDiff, _ t: ResolvedTheme) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(diff, t)

                    if triageMode {
                        triageCard(diff, t)
                    } else {
                        entryList(diff, t)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            actionBar(diff, t)
        }
    }

    @ViewBuilder
    private func header(_ diff: DisruptionService.PlanDiff, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: triggerIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(t.accent)
                Text(diff.headline)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(t.muted)
            }
            Text(warmedRationale.isEmpty ? diff.rationale : warmedRationale)
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(t.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !triageMode && !diff.isEmpty {
                Text(summaryLine(diff))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }

    /// The proposed re-plan as a list of kept / moved / dropped rows.
    @ViewBuilder
    private func entryList(_ diff: DisruptionService.PlanDiff, _ t: ResolvedTheme) -> some View {
        if diff.isEmpty {
            calmEmpty(t)
        } else {
            VStack(spacing: 10) {
                ForEach(diff.entries) { entry in
                    DiffRow(
                        entry: entry,
                        editable: isEditing && !entry.isProtected,
                        onCycle: { cycle(entry) }
                    )
                }
            }
        }
    }

    /// Triage: just the single protected next step, nothing else. The antidote to
    /// overwhelm — exactly one small thing.
    @ViewBuilder
    private func triageCard(_ diff: DisruptionService.PlanDiff, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let p = diff.protectedEntry {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Just this. The rest can wait.")
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)
                    HStack(spacing: 10) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundStyle(t.accent)
                        Text(p.title)
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(t.ink)
                    }
                    Text(p.toSlot.isEmpty ? "Anytime that works" : "Around \(p.toSlot)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.accent.opacity(0.4), lineWidth: 1))
            } else {
                Text("Nothing pressing right now. Rest is allowed.")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(t.ink)
            }
            Button {
                Haptics.light()
                withAnimation(MotionPreference.animation(.ambidashSpring)) { triageMode = false }
            } label: {
                Text("Show the full re-plan")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.accent)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func calmEmpty(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your day's already light.")
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(t.ink)
            Text("There's nothing to reshuffle — what's left already fits. Take the breath.")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Action bar

    @ViewBuilder
    private func actionBar(_ diff: DisruptionService.PlanDiff, _ t: ResolvedTheme) -> some View {
        VStack(spacing: 10) {
            Divider().background(t.hair)
            HStack(spacing: 10) {
                // Triage toggle — "just one thing" when overwhelmed.
                secondaryButton(
                    triageMode ? "Full plan" : "Just one thing",
                    icon: triageMode ? "list.bullet" : "scope",
                    t: t
                ) {
                    withAnimation(MotionPreference.animation(.ambidashSpring)) { triageMode.toggle() }
                }

                if !triageMode && !diff.isEmpty {
                    secondaryButton(isEditing ? "Done editing" : "Edit", icon: "slider.horizontal.3", t: t) {
                        withAnimation(MotionPreference.animation(.ambidashSpring)) { isEditing.toggle() }
                    }
                }
            }
            .padding(.horizontal, 22)

            Button {
                accept(diff)
            } label: {
                Text(diff.isEmpty ? "Okay" : "Accept this plan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(t.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
        .background(t.surface.opacity(0.001))
    }

    @ViewBuilder
    private func secondaryButton(_ label: String, icon: String, t: ResolvedTheme, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(t.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(t.sunken.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(t.hair, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    // MARK: - Logic

    private func buildAndWarm() async {
        let built = DisruptionService.buildDiff(
            for: plan, trigger: trigger, prefs: prefs, goals: goals
        )
        await MainActor.run {
            self.diff = built
            self.warmedRationale = built.rationale
            // Health flares open straight into the calmest framing.
            if case .healthFlare = trigger { self.triageMode = true }
        }
        let warm = await DisruptionPhrasing.rationale(for: built)
        await MainActor.run { self.warmedRationale = warm }
    }

    /// EDIT — cycle a non-protected entry through kept → moved → dropped → kept. A
    /// moved entry keeps its proposed slot; flipping to kept restores the original.
    private func cycle(_ entry: DisruptionService.DiffEntry) {
        guard var d = diff, let idx = d.entries.firstIndex(where: { $0.id == entry.id }), !entry.isProtected else { return }
        Haptics.light()
        var e = d.entries[idx]
        switch e.kind {
        case .kept:
            e.kind = .dropped
            e.toSlot = e.fromSlot
            e.why = "You chose to roll this forward."
        case .dropped:
            e.kind = .kept
            e.toSlot = e.fromSlot
            e.why = "Kept where it was."
        case .moved:
            e.kind = .dropped
            e.why = "You chose to roll this forward."
        }
        d.entries[idx] = e
        diff = d
    }

    /// ACCEPT — snapshot for reversibility, apply the non-punitive state machine,
    /// save, and hand control back. Empty diffs just dismiss calmly.
    private func accept(_ diff: DisruptionService.PlanDiff) {
        Haptics.success()
        if !diff.isEmpty {
            // Reversibility v1: DECLINE ("Not now") is loss-free because nothing is
            // mutated until this point. On ACCEPT we apply the non-punitive state
            // machine (moved = new timeSlot; dropped = .deferred, which
            // CarryOverService rolls forward to tomorrow). `DisruptionService.snapshot`
            // + `revert` remain available for a host that wants an explicit post-accept
            // undo banner.
            DisruptionService.apply(diff, to: plan)
            try? modelContext.save()
            // Re-sync the escalating reminder chains to the reshaped day: moved
            // blocks get their chain rebuilt at the new time, dropped (now .deferred)
            // blocks get theirs cancelled. Idempotent per block.
            NotificationService.scheduleChains(for: plan.actions ?? [], on: plan.date)
            onApplied()
        }
        dismiss()
    }

    // MARK: - Presentation helpers

    private var triggerIcon: String {
        switch trigger {
        case .manual:          return "arrow.triangle.2.circlepath"
        case .lowEnergy:       return "battery.25"
        case .missedBlocks:    return "clock.arrow.circlepath"
        case .calendarOverrun: return "calendar.badge.exclamationmark"
        case .healthFlare:     return "heart.text.square"
        }
    }

    private func summaryLine(_ diff: DisruptionService.PlanDiff) -> String {
        var parts: [String] = []
        if diff.movedCount > 0 { parts.append("\(diff.movedCount) moved") }
        if diff.droppedCount > 0 { parts.append("\(diff.droppedCount) rolls forward") }
        if diff.protectedEntry != nil { parts.append("1 protected") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Diff row

/// One line of the proposed re-plan. KEPT reads plainly; MOVED shows the
/// "08:00 → 18:00" shift; DROPPED reads as a gentle roll-forward. Every state uses
/// the soft `deferred` token for moved/dropped and the accent for the protected pick
/// — NEVER red. In edit mode the row is tappable to cycle its state.
private struct DiffRow: View {
    @Environment(ThemeManager.self) private var tm
    let entry: DisruptionService.DiffEntry
    let editable: Bool
    let onCycle: () -> Void

    var body: some View {
        let t = tm.resolved
        Button {
            if editable { onCycle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kindIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint(t))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.title)
                            .font(.system(size: 15, weight: entry.isProtected ? .semibold : .regular))
                            .foregroundStyle(entry.kind == .dropped ? t.muted : t.ink)
                            .lineLimit(2)
                        if entry.isProtected {
                            Text("PROTECTED")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(t.accent)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(t.accentSoft)
                                .clipShape(Capsule())
                        }
                        Spacer(minLength: 4)
                        timeLabel(t)
                    }
                    Text(entry.why)
                        .font(.system(size: 11))
                        .foregroundStyle(t.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(t))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(entry.isProtected ? t.accent.opacity(0.5) : t.hair, lineWidth: entry.isProtected ? 1 : 0.5)
            )
            .opacity(entry.kind == .dropped ? 0.7 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
        .accessibilityHint(editable ? "Double tap to change keep, move, or roll forward." : "")
    }

    @ViewBuilder
    private func timeLabel(_ t: ResolvedTheme) -> some View {
        switch entry.kind {
        case .moved where !entry.fromSlot.isEmpty && entry.fromSlot != entry.toSlot:
            HStack(spacing: 4) {
                Text(entry.fromSlot)
                    .strikethrough(true, color: t.deferred)
                    .foregroundStyle(t.deferred)
                Image(systemName: "arrow.right").font(.system(size: 8))
                    .foregroundStyle(t.deferred)
                Text(entry.toSlot.isEmpty ? "—" : entry.toSlot)
                    .foregroundStyle(t.ink)
            }
            .font(.system(size: 10, design: .monospaced))
        case .dropped:
            Text("→ tomorrow")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.deferred)
        default:
            Text(entry.toSlot.isEmpty ? "Anytime" : entry.toSlot)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.faint)
        }
    }

    private var kindIcon: String {
        switch entry.kind {
        case .kept:    return entry.isProtected ? "shield.fill" : "checkmark.circle"
        case .moved:   return "arrow.turn.down.right"
        case .dropped: return "arrow.uturn.forward"
        }
    }

    private func tint(_ t: ResolvedTheme) -> Color {
        if entry.isProtected { return t.accent }
        switch entry.kind {
        case .kept:           return t.muted
        case .moved, .dropped: return t.deferred   // soft, never red
        }
    }

    private func background(_ t: ResolvedTheme) -> Color {
        if entry.isProtected { return t.accentSoft }
        return t.sunken.opacity(entry.kind == .dropped ? 0.3 : 0.45)
    }

    private var a11y: String {
        let state: String
        switch entry.kind {
        case .kept:    state = entry.isProtected ? "protected, kept" : "kept"
        case .moved:   state = "moved from \(entry.fromSlot) to \(entry.toSlot)"
        case .dropped: state = "rolls forward to tomorrow"
        }
        return "\(entry.title), \(state). \(entry.why)"
    }
}
