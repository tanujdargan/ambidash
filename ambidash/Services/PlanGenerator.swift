// ambidash/Services/PlanGenerator.swift
import Foundation

enum PlanGenerator {
    struct ActionTemplate {
        let title: String
        let goalTitle: String
        let goalID: UUID
        let domain: GoalDomain
        var durationMinutes: Int
        let why: String
        /// A2 / #10 — if-then implementation-intention anchor (e.g. "after breakfast").
        /// Empty when the template carries no cue.
        var cueTrigger: String = ""
        /// A2 / #10 — quantitative target sized to the action (reps / min / pages).
        /// nil when the action isn't naturally quantified.
        var targetAmount: Double? = nil
        /// A2 / #10 — unit for `targetAmount`. Empty when there's no target.
        var targetUnit: String = ""
    }

    /// PLAN REWRITE — one fully-formed, time-bound entry in the day's woven
    /// timeline. Covers fixed anchors, daily routines, AND goal-work, so the
    /// offline planner emits a single concrete timeline (not a list of nags). The
    /// caller materializes these into `PlannedAction`s.
    struct TimelineAction {
        var title: String
        var why: String
        /// Sortable HH:MM scheduling key.
        var timeSlot: String
        /// Instruction-style cue when not a hard clock time ("Before 13:00").
        var scheduleCue: String
        var durationMinutes: Int
        var anchorType: PlannedAction.AnchorKind
        // Goal-work-only fields (empty/nil for fixed + routine entries).
        var goalID: UUID? = nil
        var goalTitle: String? = nil
        var cueTrigger: String = ""
        var targetAmount: Double? = nil
        var targetUnit: String = ""
    }

    /// A2 / #10 — a rotating set of if-then implementation-intention anchors. The
    /// planner attaches one per action (cycled by slot index) so each action is
    /// tied to an existing daily rhythm rather than floating free.
    static let cueAnchors = [
        "after your morning coffee",
        "right after lunch",
        "before you open your laptop",
        "as soon as you get home",
        "before dinner",
        "right after you wake up",
        "before you wind down tonight",
        "the moment you feel the urge to scroll",
    ]

    /// A2 / #10 — derives a quantitative target (amount + unit) for an action on a
    /// given goal, when the goal is naturally measurable or habitual. Returns
    /// (nil, "") when there is no sensible quantity to surface.
    ///
    /// For measurable goals we size a single-session increment from the remaining
    /// gap to target spread over a month of sessions; for habitual goals we surface
    /// a duration-as-minutes target so "show up" becomes "20 min". Otherwise none.
    static func quantitativeTarget(for goal: Goal, durationMinutes: Int) -> (amount: Double?, unit: String) {
        if goal.hasTarget {
            let remaining = abs(goal.targetValue - goal.currentValue)
            guard remaining > 0 else { return (nil, "") }
            // Aim to close the gap over ~20 working sessions; keep at least 1 unit.
            let perSession = max((remaining / 20).rounded(), 1)
            let unit = goal.unit.isEmpty ? "units" : goal.unit
            return (perSession, unit)
        }
        if goal.isHabitual {
            // Habitual goals: surface the session length as a concrete "X min".
            return (Double(durationMinutes), "min")
        }
        return (nil, "")
    }

    static let domainTemplates: [GoalDomain: [(String, Int, String)]] = [
        .body: [
            ("Workout session", 45, "Consistency builds the body you want"),
            ("30-minute walk", 30, "Active recovery and fresh air"),
            ("Stretching routine", 15, "Flexibility prevents injury"),
        ],
        .mind: [
            ("Deep reading session", 45, "Build knowledge that compounds"),
            ("Learn something new (video/article)", 30, "Expand your mental models"),
            ("Practice recall on recent learning", 20, "Retrieval strengthens memory"),
            ("Language practice", 20, "Daily practice builds fluency"),
            ("Phone-free block", 60, "Reclaim your attention"),
            ("Delete or mute one notification source", 5, "Reduce digital noise"),
        ],
        .craft: [
            ("Deep work on main project", 90, "Focused work moves the needle"),
            ("Code review or skill practice", 45, "Sharpen the saw"),
            ("Research/planning session", 30, "Strategy before execution"),
        ],
        .people: [
            ("Reach out to one person", 10, "Relationships need maintenance"),
            ("Social challenge: start a conversation", 15, "Growth happens outside comfort zones"),
        ],
        .wealth: [
            ("Review budget or spending", 20, "Awareness drives better decisions"),
            ("Work on income-generating project", 60, "Build assets, not just habits"),
        ],
        .adventure: [
            ("Do something new today", 60, "Novel experiences expand who you are"),
            ("Plan an experience", 20, "Anticipation is half the joy"),
        ],
    ]

    static func templates(for domain: GoalDomain) -> [(String, Int, String)] {
        domainTemplates[domain] ?? []
    }

    /// F3 — a goalType-aware action shaped to *how* the goal is pursued. Returns
    /// nil for types with no specific override so the caller falls back to the
    /// per-domain templates. Habit/recurring actions are sized to cadence.
    static func typeTemplate(for goal: Goal) -> (String, Int, String)? {
        // PLAN REWRITE — prefer the user's own goal-specific detail when present so
        // the action reads like a real task ("45 min push/pull/legs at campus gym")
        // rather than a generic nag. `details` is free text from the goal card.
        let detail = goal.details.trimmingCharacters(in: .whitespaces)
        switch goal.goalType {
        case .habit:
            // Only append the em-dash detail when the user gave one; otherwise the
            // title would duplicate ("Meditate — Meditate"). Bare title reads fine.
            let title = detail.isEmpty ? goal.title : "\(goal.title) — \(detail)"
            return (title, 20,
                    "Daily consistency is the whole game for this one")
        case .recurring:
            let what = detail.isEmpty ? "\(goal.title) session" : detail
            return ("\(what)", 45,
                    "Hit your weekly cadence — adherence beats intensity")
        case .project:
            let what = detail.isEmpty ? goal.title : detail
            return ("Work block: \(what)", 60,
                    "Projects move forward one concrete step at a time")
        case .milestone:
            let what = detail.isEmpty ? goal.title : detail
            return ("Work block: \(what)", 45,
                    "Close the gap to this checkpoint")
        case .accumulation:
            let unit = goal.unit.isEmpty ? "the number" : goal.unit
            let what = detail.isEmpty ? "Move \(unit) on \(goal.title)" : detail
            return ("\(what)", 30,
                    "Small, regular gains compound toward the target")
        }
    }

    /// Ordered action candidates for a goal: the goalType-aware action first (if
    /// any), then the per-domain templates as fallback. Additive refinement over
    /// the prior domain-only selection.
    static func candidateTemplates(for goal: Goal) -> [(String, Int, String)] {
        let domain = domainTemplates[goal.domain] ?? []
        if let typed = typeTemplate(for: goal) {
            return [typed] + domain
        }
        return domain
    }

    static func generateActions(
        for goals: [Goal],
        freeMinutes: Int,
        maxActions: Int,
        learned: LearnedProfile? = nil
    ) -> [ActionTemplate] {
        let active = goals.filter(\.isActive)
        guard !active.isEmpty else { return [] }

        let sorted = active.sorted { a, b in
            if a.neglectDays != b.neglectDays { return a.neglectDays > b.neglectDays }
            return a.priority < b.priority
        }

        // LEARNING — re-size a candidate template to the user's logged median for that
        // goal BEFORE it's selected/budgeted, so selection, the `<= remainingMinutes`
        // budget check, AND downstream slotting all see the SAME (learned) duration.
        // (Previously the learned size was applied only AFTER selection, so a goal
        // admitted on its 20m template but re-sized to 90m would routinely fail the
        // gap-fit and be silently dropped — the most-learned-about goals most often.)
        // Identity no-op without a usable profile.
        let hasLearning = (learned?.isEmpty == false)
        func adjusted(_ base: (String, Int, String), for goal: Goal) -> (String, Int, String) {
            guard hasLearning, let learned else { return base }
            return (base.0, learned.adjustedDuration(forGoal: goal.id, default: base.1), base.2)
        }

        var result: [ActionTemplate] = []
        var remainingMinutes = freeMinutes
        var usedKeys: Set<String> = []

        for goal in sorted {
            if result.count >= maxActions || remainingMinutes <= 0 { break }

            // F3 — prefer a goalType-aware action, then fall back to per-domain templates.
            let temps = candidateTemplates(for: goal).map { adjusted($0, for: goal) }
            guard let t = temps.first(where: { $0.1 <= remainingMinutes && !usedKeys.contains("\(goal.title)-\($0.0)") }) else { continue }

            result.append(buildTemplate(for: goal, base: t, slotIndex: result.count))
            remainingMinutes -= t.1
            usedKeys.insert("\(goal.title)-\(t.0)")
        }

        if result.count < maxActions {
            for goal in sorted where result.count < maxActions && remainingMinutes > 0 {
                let temps = candidateTemplates(for: goal).map { adjusted($0, for: goal) }
                for t in temps {
                    let key = "\(goal.title)-\(t.0)"
                    if !usedKeys.contains(key) && t.1 <= remainingMinutes && result.count < maxActions {
                        result.append(buildTemplate(for: goal, base: t, slotIndex: result.count))
                        remainingMinutes -= t.1
                        usedKeys.insert(key)
                        break
                    }
                }
            }
        }

        return result
    }

    /// PLAN REWRITE — the offline timeline. Weaves the user's FIXED ANCHORS and
    /// DAILY ROUTINES (from `prefs`, via `DailyTimeline`) together with GOAL-WORK
    /// slotted into the day's free gaps, producing one concrete, time-ordered
    /// timeline. Every entry carries a clock time (or relative cue) + duration so
    /// the offline plan is genuinely good without any AI.
    ///
    /// When `prefs` is nil (no preferences set) it falls back to a goal-work-only
    /// timeline scheduled across the default waking window — i.e. the prior
    /// behaviour, but still concrete.
    ///
    /// LEARNING ENGINE (build-order #3) — when a `learned` profile is supplied, the
    /// timeline adapts to how the user ACTUALLY lives instead of the fixed defaults:
    /// goal-work durations are re-estimated from the user's median logged time per
    /// goal, and goal-work is anchored to the user's REAL inferred wake/sleep when
    /// those diverge from the `UserPreferences` targets. Every adjustment is traceable
    /// via the profile's `explain*` helpers. The profile also carries adherence- and
    /// energy-by-hour signals (exposed for callers/UI as placement hints), but those
    /// are advisory only here — they never block or reorder a block. `learned == nil`
    /// (or an empty profile) is a strict no-op — identical output to before — so day-1
    /// users see no change.
    static func generateTimeline(
        for goals: [Goal],
        prefs: UserPreferences?,
        freeMinutes: Int?,
        maxGoalActions: Int,
        learned: LearnedProfile? = nil
    ) -> [TimelineAction] {
        let skeleton = DailyTimeline.skeleton(from: prefs)

        // 1) Fixed + routine entries become timeline actions verbatim.
        var timeline: [TimelineAction] = skeleton.map { e in
            TimelineAction(
                title: e.title,
                why: e.why,
                timeSlot: e.clock,
                scheduleCue: e.scheduleCue,
                durationMinutes: e.durationMinutes,
                anchorType: e.kind
            )
        }

        // 2) Goal-work slotted into the free gaps between anchors.
        // LEARNING — the learned per-goal median duration is applied INSIDE
        // generateActions, BEFORE selection/budgeting, so the same (learned) size
        // drives selection, the free-minutes budget, AND the slotting below. This
        // means a goal whose learned typical far exceeds its template is budgeted at
        // its real cost rather than admitted cheap and then dropped at slot time.
        let budget = freeMinutes ?? DailyTimeline.freeGaps(in: skeleton).reduce(0) { $0 + $1.minutes }
        let goalActions = generateActions(
            for: goals,
            freeMinutes: max(budget, 30),
            maxActions: maxGoalActions,
            learned: learned
        )

        // Gaps stay in chronological order so the bedtime guard (which relies on the
        // last gap being the latest in the day) holds. Adherence is applied as a
        // per-action placement bias inside the slotting loop below, not by reordering.
        let gaps = DailyTimeline.freeGaps(in: skeleton)

        // Hard upper bound for goal-work: nothing may be scheduled to end past the
        // user's sleep time / day end. Derive it from the last gap's end (which is
        // the day end = sleep anchor) when gaps exist, else the prefs sleep time,
        // else a sane default. Overflow that can't fit before this is dropped
        // rather than appended sequentially past bedtime.
        var dayEnd = gaps.last?.endMinutes
            ?? prefs.flatMap { DailyTimeline.minutes(from: $0.sleepTime) }
            ?? (23 * 60 + 30)

        var gapIndex = 0
        var cursorInGap = gaps.first?.startMinutes ?? (9 * 60)

        // LEARNING — anchor goal-work to the user's REAL active hours when we have
        // enough confidence (≥2 logged days). We only ever TIGHTEN within the
        // existing window — never schedule goal-work before the user actually wakes,
        // nor let it run past when they actually sleep — so the user-set anchors stay
        // put and the bedtime guard still holds. Identity no-op without a profile.
        if let learned, learned.wakeSleepDayCount >= 2 {
            if let realWake = learned.realWakeMinutes {
                cursorInGap = max(cursorInGap, realWake)
            }
            if let realSleep = learned.realSleepMinutes, realSleep > cursorInGap {
                dayEnd = min(dayEnd, realSleep)
            }
        }
        for tmpl in goalActions {
            // Advance to a gap that can hold this action; spill into the last gap.
            while gapIndex < gaps.count,
                  cursorInGap + tmpl.durationMinutes > gaps[gapIndex].endMinutes {
                gapIndex += 1
                cursorInGap = gapIndex < gaps.count ? gaps[gapIndex].startMinutes : cursorInGap
            }
            let start: Int
            if gapIndex < gaps.count {
                start = cursorInGap
                cursorInGap += tmpl.durationMinutes + 10
            } else {
                // No gap left — try to append after the last placed item, but never
                // past the day end / sleep time. Drop the overflow instead.
                guard cursorInGap + tmpl.durationMinutes <= dayEnd else { continue }
                start = cursorInGap
                cursorInGap += tmpl.durationMinutes + 10
            }
            // Final guard for the in-gap path too: never let an action run past the
            // day end / sleep time, even if a gap nominally allowed it.
            guard start + tmpl.durationMinutes <= dayEnd else { continue }
            timeline.append(TimelineAction(
                title: tmpl.title,
                why: tmpl.why,
                timeSlot: DailyTimeline.Entry.format(start),
                scheduleCue: "",
                durationMinutes: tmpl.durationMinutes,
                anchorType: .goalWork,
                goalID: tmpl.goalID,
                goalTitle: tmpl.goalTitle,
                cueTrigger: tmpl.cueTrigger,
                targetAmount: tmpl.targetAmount,
                targetUnit: tmpl.targetUnit
            ))
        }

        return timeline.sorted { $0.timeSlot < $1.timeSlot }
    }

    /// A2 / #10 — wraps a chosen base template tuple into a fully-formed
    /// `ActionTemplate`, attaching an if-then cue (cycled by slot index) and a
    /// quantitative target when the goal is measurable/habitual.
    ///
    /// PLAN REWRITE — goal-work is now placed at a concrete clock time on the woven
    /// timeline, so the title is kept CLEAN (no "After your coffee:" prefix that
    /// would fight the assigned time). The if-then cue still rides along in
    /// `cueTrigger` for the small tag the timeline row renders.
    private static func buildTemplate(for goal: Goal, base: (String, Int, String), slotIndex: Int) -> ActionTemplate {
        let cue = cueAnchors[slotIndex % cueAnchors.count]
        let (amount, unit) = quantitativeTarget(for: goal, durationMinutes: base.1)

        var title = base.0
        if let amount, !unit.isEmpty, !title.lowercased().contains(unit.lowercased()) {
            title += " — \(formatAmount(amount)) \(unit)"
        }

        return ActionTemplate(
            title: title,
            goalTitle: goal.title,
            goalID: goal.id,
            domain: goal.domain,
            durationMinutes: base.1,
            why: base.2,
            cueTrigger: cue,
            targetAmount: amount,
            targetUnit: unit
        )
    }

    /// Formats a target amount as an int when whole, else one decimal place.
    private static func formatAmount(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    // MARK: - CLOSING RITUAL — tomorrow's ONE protected thing

    /// CLOSING RITUAL — when the user named tomorrow's ONE most-important thing in
    /// last night's closing ritual, surface it as a PROTECTED, top-of-day block that
    /// the plan is built around (the "keep your ONE thing" intent DisruptionService
    /// also honors). Returns a `TimelineAction` to prepend, or nil when no one-thing
    /// was set / it's blank.
    ///
    /// Placement: pinned early (07:00 sort key) so it sorts to the front of the day
    /// without colliding with the user's fixed wake/meal anchors' own slots; it reads
    /// as the day's headline, not a clock-locked block. `anchorType` stays `.goalWork`
    /// so existing surfaces treat it as real, carry-forward-eligible work.
    ///
    /// Pure: no fetch/save. The caller resolves the latest reflection's
    /// `tomorrowOneThing` and passes it in.
    static func oneThingAction(
        title rawTitle: String,
        goalID: UUID? = nil,
        goalTitle: String? = nil
    ) -> TimelineAction? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return TimelineAction(
            title: title,
            why: "Your one most-important thing for today — chosen last night. Protect it.",
            timeSlot: "07:00",
            scheduleCue: "Your one thing — first",
            durationMinutes: 45,
            anchorType: .goalWork,
            goalID: goalID,
            goalTitle: goalTitle
        )
    }
}
