import SwiftUI
import SwiftData

/// FOCUS SESSION — a calm, visible countdown for either the CURRENT timeline block or
/// a quick free session (default 25m). Start / pause / stop, a gentle (never guilt)
/// completion, an optional looping soundscape, and a LOCAL "body-double" presence
/// affordance.
///
/// The countdown reuses the proven, zero-wakeup pattern from `DailyTimelineComponent`:
/// `Text(timerInterval:countsDown:)` is ticked by the system clock, so a running
/// session costs nothing while visible. A 1s `minuteTick` only re-resolves "is a block
/// still current" and drives the completion check.
///
/// The session itself is EPHEMERAL — it lives in `@State`, never in SwiftData/CloudKit
/// (no new @Model). When a session finishes against a real block, it optionally folds
/// an inferred `ActualEvent` into the store so focus work feeds the wins/learning loop,
/// reusing the existing `LearningService.inferredEvent` substrate.
///
/// Calm by default; all motion routes through `MotionPreference`, all feedback through
/// `Haptics`. The body-double presence is an explicit LOCAL stub — it never implies
/// real people or networking.
struct FocusSessionComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let boardData: BoardData

    // MARK: Session state (ephemeral — never persisted)

    private enum Phase: Equatable { case idle, running, paused, finished }

    /// What the session is anchored to: a real timeline block, or a free pomodoro.
    private enum Target: Equatable {
        case block(UUID)      // the PlannedAction.id this session covers
        case free(minutes: Int)
    }

    @State private var phase: Phase = .idle
    @State private var target: Target = .free(minutes: 25)
    /// The concrete deadline the countdown runs toward (set on start, on pause-resume).
    @State private var endDate: Date = .now
    /// Remaining seconds captured at pause, so resume continues from where it stopped.
    @State private var pausedRemaining: TimeInterval = 0
    @State private var now: Date = .now

    /// Chosen free-session length when not anchored to a block.
    @State private var freeMinutes: Int = 25
    private static let freeOptions = [10, 15, 25, 45]

    /// Local-only body-double presence. A stub — never a real network of people.
    @State private var presenceOn = false
    /// Optional on-device AI "still with me?" check-in line, gated + best-effort.
    @State private var aiCheckinLine: String?
    @State private var lastCheckinFireMinute: Int = -1

    /// Soundscape toggle, mirrored from prefs at appear; only meaningful if a sound is
    /// actually bundled (otherwise the toggle is hidden — honest affordance).
    @State private var soundOn = false
    #if os(iOS)
    @State private var sound = FocusSoundService()
    #endif

    /// 1s tick: re-resolves the current block + checks for completion. The visible
    /// countdown ticks itself via `Text(timerInterval:)`, so this stays cheap.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            header(t)

            switch phase {
            case .idle:
                idleBody(t)
            case .running, .paused:
                runningBody(t)
            case .finished:
                finishedBody(t)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .animation(MotionPreference.animation(.ambidashSpring), value: phase)
        .onAppear {
            now = .now
            soundOn = boardData.profile?.userPreferences?.focusSoundEnabled ?? false
            freeMinutes = defaultFreeMinutes
        }
        .onReceive(tick) { value in
            now = value
            if phase == .running { evaluateCompletion() ; maybeFireCheckin() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Leave no audio footprint when backgrounded; pause a running session's
            // sound (the countdown itself is wall-clock based and stays correct).
            if newPhase != .active { stopSound() }
            else if phase == .running, soundOn { startSound() }
        }
        .onDisappear {
            // When this component scrolls out of the LazyVStack or the user switches
            // tabs, scenePhase stays `.active`, so the soundscape would otherwise keep
            // looping unheard. Stop the audio and quiet the session timer: pause a
            // running session so the 1s tick stops driving completion/check-in/sound
            // work for a view that's no longer on screen.
            stopSound()
            if phase == .running { pause() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus session")
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title: "Focus")
            Spacer()
            if phase == .running || phase == .paused {
                Text(phase == .paused ? "paused" : "in focus")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }

    // MARK: - Idle

    @ViewBuilder
    private func idleBody(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let block = currentBlock {
                // Offer the CURRENT block first — the most useful default.
                focusOnBlockCard(t, block: block, headline: "Focus on what's now")
            } else if let next = upcomingBlock {
                focusOnBlockCard(t, block: next, headline: "Get a head start")
            } else {
                Text("Pick a length and settle into one thing. No streak, no pressure — just a calm timer.")
                    .font(t.body(12))
                    .foregroundStyle(t.muted)
            }

            // Free-session length picker (always available as an alternative).
            VStack(alignment: .leading, spacing: 8) {
                Text(currentBlock == nil && upcomingBlock == nil ? "Length" : "Or a quick session")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(t.faint)
                HStack(spacing: 8) {
                    ForEach(Self.freeOptions, id: \.self) { mins in
                        lengthChip(t, minutes: mins)
                    }
                }
                Button {
                    Haptics.medium()
                    startFree(minutes: freeMinutes)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 12))
                        Text("Start \(freeMinutes)-min focus")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(t.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
            }
        }
    }

    @ViewBuilder
    private func focusOnBlockCard(_ t: ResolvedTheme, block: TimelineBlock, headline: String) -> some View {
        Button {
            Haptics.medium()
            startOnBlock(block)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(t.faint)
                HStack(spacing: 8) {
                    Image(systemName: "target").font(.system(size: 13))
                    Text(block.action.title)
                        .font(t.body(15))
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(remainingLabel(for: block))
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(t.muted)
                }
                .foregroundStyle(t.ink)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                    Text("Start focusing").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(t.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.accent.opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    @ViewBuilder
    private func lengthChip(_ t: ResolvedTheme, minutes: Int) -> some View {
        let on = freeMinutes == minutes
        Button {
            Haptics.light()
            freeMinutes = minutes
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 13, weight: on ? .semibold : .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(on ? t.accent : t.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
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
        .accessibilityLabel("\(minutes) minute focus")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - Running / paused

    @ViewBuilder
    private func runningBody(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // What we're focusing on.
            Text(focusTitle)
                .font(t.body(15))
                .fontWeight(.semibold)
                .foregroundStyle(t.ink)
                .lineLimit(2)

            // The big calm countdown ring + time.
            HStack(spacing: 18) {
                progressRing(t)
                VStack(alignment: .leading, spacing: 4) {
                    if phase == .running, endDate > now {
                        Text(timerInterval: now...endDate, countsDown: true)
                            .font(.system(size: 30, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(t.ink)
                    } else {
                        Text(Self.clock(pausedRemaining))
                            .font(.system(size: 30, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(phase == .paused ? t.muted : t.ink)
                    }
                    Text(phase == .paused ? "paused — pick up when you're ready" : "remaining")
                        .font(.system(size: 11))
                        .foregroundStyle(t.muted)
                }
                Spacer(minLength: 0)
            }

            // Body-double presence (local stub) + optional AI check-in line.
            presenceRow(t)

            // Controls.
            HStack(spacing: 10) {
                controlButton(t, label: phase == .paused ? "Resume" : "Pause",
                              icon: phase == .paused ? "play.fill" : "pause.fill",
                              prominent: phase == .paused) {
                    phase == .paused ? resume() : pause()
                }
                controlButton(t, label: "Done", icon: "checkmark", prominent: false) {
                    finish(reachedEnd: false)
                }
            }

            soundscapeToggle(t)
        }
    }

    @ViewBuilder
    private func progressRing(_ t: ResolvedTheme) -> some View {
        ZStack {
            Circle()
                .stroke(t.hair, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(t.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(MotionPreference.animation(.ambidashSpring), value: progressFraction)
            Image(systemName: phase == .paused ? "pause" : "timer")
                .font(.system(size: 16))
                .foregroundStyle(t.accent)
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func presenceRow(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.light()
                withAnimation(MotionPreference.animation(.ambidashSpring)) { presenceOn.toggle() }
            } label: {
                HStack(spacing: 8) {
                    BreathingDot(active: presenceOn, color: t.accent)
                    Text(presenceOn ? presenceCopy : "Focus alongside someone")
                        .font(.system(size: 12))
                        .foregroundStyle(presenceOn ? t.ink2 : t.muted)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: presenceOn ? "person.2.fill" : "person.2")
                        .font(.system(size: 11))
                        .foregroundStyle(presenceOn ? t.accent : t.faint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.sunken.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(t.hair, lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleOnPress()

            if let line = aiCheckinLine {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 10))
                    Text(line)
                        .font(.system(size: 11))
                        .italic()
                }
                .foregroundStyle(t.deferred)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func controlButton(_ t: ResolvedTheme, label: String, icon: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(prominent ? t.accent : t.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(prominent ? t.accentSoft : t.sunken.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(prominent ? t.accent.opacity(0.5) : t.hair, lineWidth: prominent ? 1 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    @ViewBuilder
    private func soundscapeToggle(_ t: ResolvedTheme) -> some View {
        #if os(iOS)
        // Only offer the toggle when a bundled sound actually exists — never a control
        // that silently does nothing.
        if FocusSoundService.hasBundledSound {
            Button {
                Haptics.light()
                soundOn.toggle()
                boardData.profile?.userPreferences?.focusSoundEnabled = soundOn
                try? modelContext.save()
                if soundOn, phase == .running { startSound() } else { stopSound() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.system(size: 11))
                    Text(soundOn ? "Soundscape on" : "Soundscape off")
                        .font(.system(size: 12))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(soundOn ? t.accent : t.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.sunken.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleOnPress()
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Finished (gentle completion)

    @ViewBuilder
    private func finishedBody(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(t.ok)
                VStack(alignment: .leading, spacing: 3) {
                    Text("That's a focused stretch.")
                        .font(t.body(15))
                        .fontWeight(.semibold)
                        .foregroundStyle(t.ink)
                    Text(completionSubtitle)
                        .font(t.body(12))
                        .foregroundStyle(t.muted)
                }
                Spacer(minLength: 0)
            }

            Button {
                Haptics.light()
                resetToIdle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 12))
                    Text("Another?").font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(t.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleOnPress()
        }
    }

    // MARK: - Block derivation (mirror DailyTimelineComponent)

    /// Today's actions resolved into renderable blocks, ordered by clock time. Mirrors
    /// `DailyTimelineComponent.blocks` so the two surfaces agree on what's "current".
    private var blocks: [TimelineBlock] {
        guard let plan = boardData.todayPlan else { return [] }
        let actions = (plan.actions ?? [])
        guard !actions.isEmpty else { return [] }
        let resolved: [TimelineBlock] = actions.map { action in
            let parsed = DailyTimeline.minutes(from: action.timeSlot)
            return TimelineBlock(
                action: action,
                startMinutes: parsed ?? 0,
                durationMinutes: max(0, action.durationMinutes),
                isScheduled: parsed != nil
            )
        }
        return resolved.sorted { a, b in
            if a.isScheduled != b.isScheduled { return a.isScheduled }
            return a.startMinutes < b.startMinutes
        }
    }

    private var currentBlock: TimelineBlock? {
        let n = TimelineBlock.nowMinutes(now)
        return blocks.first { $0.isScheduled && $0.startMinutes <= n && n < $0.endMinutes
            && $0.action.lifecycle != .done && $0.action.lifecycle != .abandoned }
    }

    private var upcomingBlock: TimelineBlock? {
        let n = TimelineBlock.nowMinutes(now)
        return blocks.first { $0.isScheduled && $0.startMinutes > n
            && $0.action.lifecycle != .done && $0.action.lifecycle != .abandoned }
    }

    /// Calm "Xm left" label for a block in the idle card.
    private func remainingLabel(for block: TimelineBlock) -> String {
        let n = TimelineBlock.nowMinutes(now)
        let mins = max(0, block.endMinutes - max(n, block.startMinutes))
        return mins > 0 ? "\(mins)m" : "\(block.durationMinutes)m"
    }

    // MARK: - Session lifecycle

    private func startOnBlock(_ block: TimelineBlock) {
        target = .block(block.action.id)
        let n = TimelineBlock.nowMinutes(now)
        // Run until the block's end, but never less than 1 minute (so a nearly-over
        // block still gives a usable focus window).
        let endMin = max(block.endMinutes, n + 1)
        endDate = block.endDate(reference: now)
        if endDate <= now {
            let cal = Calendar.current
            let dayStart = cal.startOfDay(for: now)
            endDate = cal.date(byAdding: .minute, value: endMin, to: dayStart) ?? now.addingTimeInterval(60)
        }
        beginRunning()
    }

    private func startFree(minutes: Int) {
        target = .free(minutes: minutes)
        endDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        beginRunning()
    }

    private func beginRunning() {
        aiCheckinLine = nil
        lastCheckinFireMinute = -1
        withAnimation(MotionPreference.animation(.ambidashSpring)) { phase = .running }
        if soundOn { startSound() }
    }

    private func pause() {
        pausedRemaining = max(0, endDate.timeIntervalSince(now))
        pauseSound()
        withAnimation(MotionPreference.animation(.ambidashSpring)) { phase = .paused }
    }

    private func resume() {
        endDate = now.addingTimeInterval(pausedRemaining)
        if soundOn { startSound() }
        withAnimation(MotionPreference.animation(.ambidashSpring)) { phase = .running }
    }

    /// Completion check on the 1s tick — when the deadline passes, finish gently.
    private func evaluateCompletion() {
        if endDate <= now { finish(reachedEnd: true) }
    }

    /// Finish the session. Gentle, positive, never guilt — even an early "Done" is
    /// framed as a win. When anchored to a real block, fold an inferred ActualEvent
    /// into the store so focus work feeds the wins/learning loop (deduped on the
    /// action id; never inserts twice).
    private func finish(reachedEnd: Bool) {
        stopSound()
        Haptics.success()
        if reachedEnd { Haptics.success() }
        logInferredEventIfBlock()
        pausedRemaining = 0
        withAnimation(MotionPreference.animation(.ambidashSpring)) { phase = .finished }
    }

    private func resetToIdle() {
        aiCheckinLine = nil
        withAnimation(MotionPreference.animation(.ambidashSpring)) { phase = .idle }
    }

    /// Fold a focus session against a real block into the wins/learning substrate by
    /// inserting an inferred ActualEvent (reusing LearningService.inferredEvent). Only
    /// when the block isn't already logged for today — deduped on linkedActionID.
    private func logInferredEventIfBlock() {
        guard case let .block(actionID) = target,
              let action = blocks.first(where: { $0.action.id == actionID })?.action else { return }
        let dayStart = Calendar.current.startOfDay(for: now)
        // Dedup: skip if an actual already links this action today.
        let already = (try? modelContext.fetch(FetchDescriptor<ActualEvent>(
            predicate: #Predicate { $0.linkedActionID == actionID && $0.date == dayStart }
        )))?.isEmpty == false
        guard !already else { return }
        // inferredEvent requires the action be marked done; a focus session is itself
        // evidence of doing the work, so build the actual directly from the block.
        guard let start = DailyTimeline.minutes(from: action.timeSlot) else { return }
        let event = ActualEvent(
            title: action.title,
            startMinutes: start,
            endMinutes: start + max(0, action.durationMinutes),
            date: dayStart,
            sourceRaw: ActualEventSource.inferred.rawValue,
            completionStatusRaw: ActualCompletionStatus.completed.rawValue,
            linkedActionID: action.id,
            linkedGoalID: action.goalID
        )
        modelContext.insert(event)
        try? modelContext.save()
    }

    // MARK: - Body-double presence (LOCAL stub)

    /// A rotating, calm companion line. Explicitly a LOCAL stub — there is no backend,
    /// no real people, no networking. Honest copy keeps the privacy posture intact.
    private var presenceCopy: String {
        let lines = [
            "Focusing alongside you — you're not doing this alone.",
            "A quiet companion is heads-down with you right now.",
            "Someone's in their own focus block too. Keep going.",
            "You + a calm presence, both at work.",
        ]
        let idx = abs(Calendar.current.component(.minute, from: now)) % lines.count
        return lines[idx]
    }

    // MARK: - Optional on-device AI check-in (gated, best-effort)

    /// Fire an AI "still with me? N min left" line ONCE, roughly mid-session, only when
    /// the user turned presence on AND a key is configured. The timer never depends on
    /// this — it's pure delight. Falls back to a warm local line if AI is unavailable.
    private func maybeFireCheckin() {
        guard presenceOn else { return }
        let remaining = endDate.timeIntervalSince(now)
        let total = totalDuration
        guard total > 120, remaining > 30 else { return }
        // Fire near the halfway point, once.
        let halfway = total / 2
        guard remaining <= halfway, lastCheckinFireMinute < 0 else { return }
        lastCheckinFireMinute = Int(remaining / 60)
        let minsLeft = max(1, Int((remaining / 60).rounded()))
        // Immediate warm fallback so something shows even offline.
        withAnimation(MotionPreference.animation(.ambidashSpring)) {
            aiCheckinLine = "Still with me? About \(minsLeft) min left — one breath, keep going."
        }
        #if os(iOS)
        guard AIConfig.isConfigured else { return }
        let title = focusTitle
        Task { @MainActor in
            let prompt = "In ONE short, warm, calm sentence (max 14 words), gently check in on someone \(minsLeft) minutes into focusing on \"\(title)\". No exclamation, no pressure, no emoji."
            if let line = try? await AIService.rawCompletion(prompt: prompt) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, phase == .running {
                    withAnimation(MotionPreference.animation(.ambidashSpring)) { aiCheckinLine = trimmed }
                }
            }
        }
        #endif
    }

    // MARK: - Derived

    private var focusTitle: String {
        switch target {
        case .block(let id):
            return blocks.first(where: { $0.action.id == id })?.action.title ?? "Focus"
        case .free(let minutes):
            return "\(minutes)-minute focus"
        }
    }

    private var totalDuration: TimeInterval {
        switch target {
        case .free(let minutes): return TimeInterval(minutes * 60)
        case .block(let id):
            if let b = blocks.first(where: { $0.action.id == id }) {
                return TimeInterval(max(1, b.durationMinutes) * 60)
            }
            return 25 * 60
        }
    }

    private var progressFraction: CGFloat {
        let remaining = phase == .paused ? pausedRemaining : max(0, endDate.timeIntervalSince(now))
        let total = totalDuration
        guard total > 0 else { return 0 }
        let done = (total - remaining) / total
        return CGFloat(min(1, max(0, done)))
    }

    private var completionSubtitle: String {
        switch target {
        case .block(let id):
            let title = blocks.first(where: { $0.action.id == id })?.action.title
            return title.map { "Time on \"\($0)\" counts." } ?? "Time on this counts."
        case .free:
            return "However far you got, it counts. Rest a moment."
        }
    }

    private var defaultFreeMinutes: Int { 25 }

    // MARK: - Sound passthrough (iOS only)

    private func startSound() {
        #if os(iOS)
        sound.start()
        #endif
    }
    private func pauseSound() {
        #if os(iOS)
        sound.pause()
        #endif
    }
    private func stopSound() {
        #if os(iOS)
        sound.stop()
        #endif
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Breathing presence dot

/// A calm, slow "breathing" dot used for the body-double presence affordance. Motion
/// is gated by `MotionPreference`: with reduced motion it renders a steady dot.
private struct BreathingDot: View {
    let active: Bool
    let color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(active ? color : color.opacity(0.4))
            .frame(width: 9, height: 9)
            .scaleEffect(active && pulse ? 1.25 : 1)
            .opacity(active && pulse ? 0.7 : 1)
            .onAppear { startIfNeeded() }
            .onChange(of: active) { _, _ in startIfNeeded() }
            .accessibilityHidden(true)
    }

    private func startIfNeeded() {
        guard active, !MotionPreference.prefersReducedMotion else { pulse = false; return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
