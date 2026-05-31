import SwiftUI
import SwiftData

/// LOGGING (build-order #3) — the "How'd that go?" sheet for a timeline block. A
/// calm, <2-second confirmation of what ACTUALLY happened: did it / partly / didn't
/// (all honored), an optional energy reading, an optional actual duration tweak, and
/// an optional note. On save it writes one `ActualEvent` (the substrate the
/// LearningService reads) and, when the block reads as completed, credits the goal
/// the same way the Today screen does.
///
/// NON-PUNITIVE by construction: "Didn't, that's okay" is a first-class choice, never
/// styled with `danger`/red; a partial is honored (2 of 5 counts). Nothing here can
/// shame the user.
///
/// Owns its own `@Query` for goals (to credit progress) and the modelContext, since
/// it mutates the store. Idempotent on `linkedActionID` for the planned block so
/// re-logging updates rather than piles up.
struct BlockLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    let action: PlannedAction
    /// Called after a successful save so the parent detail sheet can also dismiss.
    var onLogged: () -> Void = {}

    @Query private var goals: [Goal]
    /// Existing actuals for THIS block (so a re-log updates the same record).
    @Query private var existingActuals: [ActualEvent]

    @State private var status: ActualCompletionStatus
    @State private var energy: Int = 0            // 0 = not reported
    @State private var actualMinutes: Int
    @State private var note: String = ""

    /// W4 — when opened from the primary "Partly" affordance on Today, the sheet
    /// pre-selects `.partial` (and a sensible half-duration) so the partial
    /// lifecycle the save() switch already drives is reachable from the main Done
    /// flow, not only the detail sheet's "How'd that go?". Defaults to `.completed`
    /// to preserve every existing call site.
    init(action: PlannedAction, initialStatus: ActualCompletionStatus = .completed, onLogged: @escaping () -> Void = {}) {
        self.action = action
        self.onLogged = onLogged
        let aid = action.id
        _existingActuals = Query(filter: #Predicate<ActualEvent> { $0.linkedActionID == aid })
        _status = State(initialValue: initialStatus)
        // A partial open seeds half the planned duration as a gentle starting
        // guess (still freely editable); any other status keeps the full estimate.
        let planned = max(0, action.durationMinutes)
        _actualMinutes = State(initialValue: initialStatus == .partial ? max(1, planned / 2) : planned)
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(action.title)
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(t.ink)
                            .padding(.top, 6)

                        statusPicker(t)
                        energyRow(t)
                        durationRow(t)
                        noteRow(t)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("How'd that go?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { hydrateFromExisting() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func statusPicker(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "What happened")
            HStack(spacing: 8) {
                ForEach(ActualCompletionStatus.allCases, id: \.self) { s in
                    let on = status == s
                    Button {
                        Haptics.light()
                        status = s
                    } label: {
                        Text(s.label)
                            .font(.system(size: 13, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? t.ink : t.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            // Non-punitive: even "Didn't" uses the soft accent/sunken,
                            // NEVER danger/red.
                            .background(on ? t.accentSoft : t.sunken.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(on ? t.accent.opacity(0.5) : t.hair, lineWidth: on ? 1 : 0.5)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
        }
    }

    @ViewBuilder
    private func energyRow(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Energy then (optional)")
            HStack(spacing: 8) {
                ForEach(EnergyLevel.allCases) { level in
                    let on = energy == level.rawValue
                    Button {
                        Haptics.light()
                        // Tap again to clear (back to "not reported").
                        energy = on ? 0 : level.rawValue
                    } label: {
                        Image(systemName: level.symbol)
                            .font(.system(size: 16))
                            .foregroundStyle(on ? t.accent : t.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(on ? t.accentSoft : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityLabel(level.label)
                }
            }
        }
    }

    @ViewBuilder
    private func durationRow(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Actual time")
            HStack(spacing: 14) {
                Button {
                    Haptics.light()
                    actualMinutes = max(0, actualMinutes - 5)
                } label: { stepGlyph("minus", t) }
                    .buttonStyle(.plain).scaleOnPress()

                Text("\(actualMinutes) min")
                    .font(.system(size: 18, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.ink)
                    .frame(minWidth: 86)

                Button {
                    Haptics.light()
                    actualMinutes += 5
                } label: { stepGlyph("plus", t) }
                    .buttonStyle(.plain).scaleOnPress()

                Spacer(minLength: 0)

                if actualMinutes != action.durationMinutes {
                    Text("planned \(action.durationMinutes)m")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
        }
    }

    @ViewBuilder
    private func stepGlyph(_ name: String, _ t: ResolvedTheme) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(t.accent)
            .frame(width: 34, height: 34)
            .background(t.sunken.opacity(0.6))
            .clipShape(Circle())
    }

    @ViewBuilder
    private func noteRow(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Note (optional)")
            TextField("Anything worth remembering…", text: $note, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(t.ink)
                .lineLimit(1...3)
                .padding(12)
                .background(t.sunken.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hair, lineWidth: 0.5))
        }
    }

    // MARK: - Hydration

    /// If this block was already logged, pre-fill from the latest existing actual so
    /// re-opening edits the same record instead of starting blank.
    private func hydrateFromExisting() {
        guard let ev = existingActuals.max(by: { $0.loggedAt < $1.loggedAt }) else { return }
        // Don't clobber an explicit `.partial` seed (the primary "Partly"
        // affordance) with a prior `.completed` log — keep the energy/duration/note
        // hydration but honor the user's just-chosen status.
        if status != .partial {
            status = ev.completionStatus
        }
        energy = ev.energyAtStart
        actualMinutes = ev.actualDurationMinutes
        note = ev.notes
    }

    // MARK: - Save

    private func save() {
        let day = Calendar.current.startOfDay(for: .now)
        let start = DailyTimeline.minutes(from: action.timeSlot)
            ?? TimelineBlock.nowMinutes(.now)
        let end = start + max(0, actualMinutes)

        // Idempotent: update an existing record for this block, else create one.
        let target = existingActuals.max(by: { $0.loggedAt < $1.loggedAt })
        if let ev = target {
            ev.completionStatus = status
            ev.energyAtStart = energy
            ev.endMinutes = ev.startMinutes + max(0, actualMinutes)
            ev.notes = note
            ev.loggedAt = .now
            ev.sourceRaw = ActualEventSource.manual.rawValue
        } else {
            let ev = ActualEvent(
                title: action.title,
                startMinutes: start,
                endMinutes: end,
                date: day,
                sourceRaw: ActualEventSource.manual.rawValue,
                completionStatusRaw: status.rawValue,
                energyAtStart: energy,
                notes: note,
                linkedActionID: action.id,
                linkedGoalID: action.goalID
            )
            modelContext.insert(ev)
        }

        // If the user also logged a standalone energy reading, persist it as an
        // EnergyCheckin so the energy pattern layer sees it (the picker is optional;
        // 0 = not reported = no check-in).
        if energy > 0 {
            let checkin = EnergyCheckin(date: .now, level: energy, note: "")
            modelContext.insert(checkin)
        }

        // Mirror the block's planned status + credit the goal, matching the Today
        // screen's contract. Only a `completed` log marks the block done; partial /
        // abandoned leave it pending so it can still gently roll forward (never a
        // failure mark).
        switch status {
        case .completed:
            if action.statusRaw != "done" {
                action.statusRaw = "done"
                action.completedAt = .now
                creditGoal()
            }
        case .partial:
            // Honored partial (2 of 5 counts): record the lifecycle + a proportional
            // progress fraction so the timeline's partial badge, the "In progress — N%"
            // label, and CarryOverService's `.partial` branch all become reachable. The
            // action keeps gently rolling forward (lifecycle .partial maps statusRaw to
            // pending) — never a failure mark.
            action.lifecycle = .partial
            action.partialProgress = min(1, max(0, Double(actualMinutes) / Double(max(1, action.durationMinutes))))
        case .abandoned:
            // "Didn't, that's okay" — settle it kindly so the user's choice is recorded
            // (archived as abandoned, never re-carried, never shamed) instead of leaving
            // a plain pending block with no trace.
            CarryOverService.letGo(action)
        }

        // The user has logged this block (done / partly / didn't) — they've engaged
        // with it, so silence its escalating reminder chain. A partial still rolls
        // forward and will get a fresh chain when tomorrow's plan is generated.
        NotificationService.cancelReminderChain(blockID: action.id.uuidString)
        // Also clear any opt-in start reminder/alarm for this block — the user has
        // engaged with it, so an unmissable alarm for its start is no longer wanted.
        AlarmService.cancel(blockID: action.id.uuidString)

        Haptics.success()
        try? modelContext.save()
        dismiss()
        onLogged()
    }

    /// Mirror TodayView.handleDone's goal-crediting so logging from the timeline
    /// advances goals/milestones consistently.
    private func creditGoal() {
        if let goalID = action.goalID, let goal = goals.first(where: { $0.id == goalID }) {
            if goal.hasTarget, let amount = action.loggedAmount, amount != 0 {
                ProgressLogService.record(goal: goal, amount: amount, source: .action, note: action.title, context: modelContext)
            } else {
                ProgressLogService.logCheckIn(goal: goal, source: .action, context: modelContext)
            }
        }
        if let milestone = action.milestone {
            let amount = (action.loggedAmount.map { $0 != 0 ? $0 : 1 }) ?? 1
            MilestoneProgressService.contribute(amount: amount, to: milestone, context: modelContext)
        }
    }
}
