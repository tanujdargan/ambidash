import SwiftUI
import SwiftData

/// CLOSING RITUAL (the most-loved Sunsama mechanic, non-punitive) — a calm
/// end-of-day sheet with three gentle beats:
///   1. CELEBRATION — "here's what you did today", rolled up from logged
///      `ActualEvent`s + completed/partial `PlannedAction`s. Partials count.
///      Deferred work is shown as "rolls forward", NEVER as a red overdue pile.
///   2. A one-line, OPTIONAL "what felt good / hard today" note (stored on the
///      day's `Reflection.freeformText`, reusing the existing reflection record).
///   3. Pick TOMORROW's ONE most-important thing — either tap a piece of
///      rolling-forward work or type a fresh intent. Persisted on the reflection's
///      `tomorrowOneThing` (+ optional `tomorrowOneThingActionID`) so the next
///      plan-generation pins it as the protected first block.
///
/// Never punitive, never a chore: every step is skippable, nothing is framed as
/// failure, and "Close the day" works even with an empty recap.
///
/// Owns its own `@Query`s + modelContext since it mutates the store. Idempotent on
/// today's reflection (re-opening updates the same record rather than stacking).
struct ClosingRitualSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \ActualEvent.date, order: .reverse) private var allActuals: [ActualEvent]

    @State private var feltNote: String = ""
    @State private var oneThingText: String = ""
    @State private var oneThingActionID: UUID? = nil
    @State private var didLoad = false
    @FocusState private var noteFocused: Bool

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

    var body: some View {
        let t = tm.resolved
        let r = recap
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header(t)
                        celebrationSection(r, t)
                        if !r.rollsForward.isEmpty {
                            rollsForwardSection(r, t)
                        }
                        feltSection(t)
                        oneThingSection(r, t)
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Close the day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                        .foregroundStyle(t.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(t.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { noteFocused = false }
                }
            }
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EVENING · " + Date.now.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(t.muted)
            Text(recap.celebration)
                .font(t.heading(24))
                .tracking(-0.3)
                .lineSpacing(2)
                .foregroundStyle(t.ink)
        }
    }

    @ViewBuilder
    private func celebrationSection(_ r: ClosingRitualService.Recap, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "What you did")
            if r.done.isEmpty {
                Text(r.restCount > 0
                     ? "You honored \(r.restCount) rest \(r.restCount == 1 ? "moment" : "moments") today. Rest is part of the work."
                     : "Nothing logged yet — and that's okay. Tomorrow is fresh.")
                    .font(.system(size: 13))
                    .foregroundStyle(t.muted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(r.done) { item in
                        doneRow(item, t)
                    }
                    if r.restCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars")
                                .font(.system(size: 12))
                                .foregroundStyle(t.deferred)
                            Text("\(r.restCount) rest \(r.restCount == 1 ? "moment" : "moments") — honored, not absence.")
                                .font(.system(size: 12))
                                .foregroundStyle(t.muted)
                        }
                        .padding(.top, 2)
                    }
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
    private func doneRow(_ item: ClosingRitualService.DoneItem, _ t: ResolvedTheme) -> some View {
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

    @ViewBuilder
    private func rollsForwardSection(_ r: ClosingRitualService.Recap, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Rolls forward")
            Text("Not missed — these gently carry on to tomorrow.")
                .font(.system(size: 11))
                .foregroundStyle(t.muted)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(r.rollsForward) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(t.deferred)
                        Text(item.title)
                            .font(.system(size: 13))
                            .foregroundStyle(t.ink2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
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
    private func feltSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SectionLabel(title: "What felt good / hard")
                Spacer(minLength: 8)
                // PHOTO-OF-NOTES — attach a photo of notes; on-device OCR offers its text.
                ReflectionPhotoButton(text: $feltNote, reflection: resolveReflection)
                // VOICE DICTATION — on-device mic streams speech into the felt-note.
                DictationMicButton(text: $feltNote)
            }
            Text("One line, if you want it. Optional.")
                .font(.system(size: 11))
                .foregroundStyle(t.faint)
            TextField("tap to write…", text: $feltNote, axis: .vertical)
                .font(t.heading(14))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(feltNote.isEmpty ? t.faint : t.ink2)
                .lineLimit(1...4)
                .padding(.top, 2)
                .focused($noteFocused)
            // PHOTO-OF-NOTES — thumbnails of photos attached to today's reflection.
            ReflectionPhotoStrip(reflection: todayReflection)
                .padding(.top, 4)
            t.hair.frame(height: 0.5).padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func oneThingSection(_ r: ClosingRitualService.Recap, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SectionLabel(title: "Tomorrow's one thing")
                Spacer(minLength: 8)
                // PHOTO-OF-NOTES — attach a photo of notes; on-device OCR offers its text.
                ReflectionPhotoButton(text: $oneThingText, reflection: resolveReflection)
                // VOICE DICTATION — on-device mic streams speech into the one-thing field.
                DictationMicButton(text: $oneThingText)
            }
            Text("If only one thing happens tomorrow, what should it be?")
                .font(t.heading(13))
                .foregroundStyle(t.ink)

            // Quick-pick from work that rolls forward (one tap).
            if !r.rollsForward.isEmpty {
                VStack(spacing: 6) {
                    ForEach(r.rollsForward) { item in
                        oneThingChoice(
                            title: item.title,
                            selected: oneThingActionID == item.actionID,
                            t: t
                        ) {
                            if oneThingActionID == item.actionID {
                                oneThingActionID = nil
                            } else {
                                oneThingActionID = item.actionID
                                oneThingText = item.title
                            }
                            Haptics.light()
                        }
                    }
                }
            }

            // Or a fresh, typed intent.
            TextField("…or write your own", text: $oneThingText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(oneThingText.isEmpty ? t.faint : t.ink)
                .lineLimit(1...3)
                .focused($noteFocused)
                .padding(10)
                .background(t.sunken.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hair.opacity(0.6), lineWidth: 0.5))
                .onChange(of: oneThingText) { _, newValue in
                    // Typing a custom intent clears the action link (it's now free text).
                    if let aid = oneThingActionID,
                       let picked = r.rollsForward.first(where: { $0.actionID == aid }),
                       picked.title != newValue {
                        oneThingActionID = nil
                    }
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
    }

    @ViewBuilder
    private func oneThingChoice(title: String, selected: Bool, t: ResolvedTheme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? t.accent : t.muted)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? t.ink : t.ink2)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(selected ? t.accentSoft : t.sunken.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? t.accent.opacity(0.5) : t.hair.opacity(0.6), lineWidth: selected ? 1 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.scalePress)
    }

    // MARK: - Load + Save

    /// Resolves today's reflection for photo attachment, creating + inserting it if absent
    /// (so a photo can be attached before "Done" persists the rest). Idempotent.
    private func resolveReflection() -> Reflection {
        if let existing = todayReflection { return existing }
        let r = Reflection()
        modelContext.insert(r)
        try? modelContext.save()
        return r
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let r = todayReflection {
            feltNote = r.freeformText
            oneThingText = r.tomorrowOneThing
            oneThingActionID = r.tomorrowOneThingActionID
        }
    }

    /// Persists the felt-note + tomorrow's-one-thing onto today's reflection
    /// (creating it if absent). Non-destructive: an empty note/one-thing simply
    /// leaves those fields unset — closing the day is never gated on filling them.
    private func save() {
        let note = feltNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let oneThing = oneThingText.trimmingCharacters(in: .whitespacesAndNewlines)

        let reflection: Reflection
        if let existing = todayReflection {
            reflection = existing
        } else {
            let r = Reflection()
            modelContext.insert(r)
            reflection = r
        }
        // Don't clobber an existing detailed reflection note when the user left the
        // closing-ritual note blank.
        if !note.isEmpty {
            reflection.freeformText = note
        }
        reflection.tomorrowOneThing = oneThing
        reflection.tomorrowOneThingActionID = oneThing.isEmpty ? nil : oneThingActionID

        try? modelContext.save()
        Haptics.success()

        // Mirror the felt-note to the cloud the same way ReflectView does, when present.
        if !note.isEmpty {
            Task { await SyncService.syncReflectionToCloud(mood: "", blockers: [], text: note) }
        }
    }
}
