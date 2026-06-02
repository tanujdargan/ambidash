// ambidash/Services/MentorPromptBuilder.swift
import Foundation

enum MentorPromptBuilder {
    /// A measurable/variance descriptor for a goal with a target, e.g.
    /// " · measurable: 12/20 lbs (60%), behind pace (on-pace today: 15 lbs)".
    private static func measurableLine(for goal: Goal) -> String {
        guard goal.hasTarget else { return "" }
        let unit = goal.unit.isEmpty ? "" : " \(goal.unit)"
        let current = format(goal.currentValue)
        let target = format(goal.targetValue)
        let expected = format(TargetMath.expectedValue(goal))
        let percent = Int((goal.percentComplete * 100).rounded())
        let pace: String
        switch TargetMath.variance(goal) {
        case .ahead: pace = "ahead of pace"
        case .onTrack: pace = "on pace"
        case .behind: pace = "BEHIND pace"
        }
        let dir = goal.direction == .increase ? "increasing" : "decreasing"
        return " · measurable: \(current)/\(target)\(unit) (\(percent)%, \(dir)), \(pace) (on-pace value today: \(expected)\(unit))"
    }

    /// A cadence/adherence descriptor for a habitual (habit/recurring) goal, e.g.
    /// " · habitual: 2 of 3 this week (recurring 3x/wk)". Empty for non-habitual goals.
    private static func habitualLine(for goal: Goal) -> String {
        guard goal.isHabitual else { return "" }
        let logged = AdherenceFormat.loggedThisWeek(for: goal)
        let target = AdherenceFormat.target(for: goal)
        let kind = goal.goalType.displayName.lowercased()
        return " · habitual: \(logged) of \(target) this week (\(kind) \(target)x/wk)"
    }

    /// How far short of this week's cadence a habitual goal is, as a fraction
    /// (0 = met or exceeded, 1 = nothing logged). Used to surface the most
    /// behind-cadence habitual goals first instead of treating off-days as neglect.
    private static func adherenceShortfall(for goal: Goal) -> Double {
        max(0, 1 - goal.adherenceThisWeek)
    }

    /// A unified attention score for ordering goals in the plan prompt. Habitual
    /// goals are scored by their weekly adherence shortfall (off-days don't count
    /// as neglect); other goals by raw neglect days. Scaling keeps a fully-missed
    /// habitual week (score 7) comparable to a week of neglect for a one-off goal.
    private static func attentionScore(for goal: Goal) -> Double {
        if goal.isHabitual {
            return adherenceShortfall(for: goal) * 7
        }
        return Double(goal.neglectDays)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func insightPrompt(goals: [Goal], snapshot: IntegrationSnapshot?, streakSummary: String) -> String {
        var context = "You are an AI mentor inside ambidash, a life dashboard app. Your role is to spot patterns the user wouldn't notice themselves.\n\n"
        context += "USER'S GOALS:\n"
        for goal in goals where goal.isActive {
            let status = goal.computedStatus.label
            let days = goal.neglectDays
            context += "- \(goal.title) (\(goal.domain.displayName)): \(status), \(days) days since progress"
            if let streak = goal.streak, streak.currentCount > 0 {
                context += ", \(streak.currentCount)-day streak"
            }
            context += measurableLine(for: goal)
            context += habitualLine(for: goal)
            context += "\n"
        }

        if let snap = snapshot {
            // PRIVACY: only a coarse rest hint + non-health free-time leave the device.
            context += "\nTODAY'S DATA:\n"
            context += "- Rest: \(snap.restHint)\n"
            context += "- Calendar free time: \(snap.calendarFreeMinutes) minutes\n"
        }

        if !streakSummary.isEmpty {
            context += "\nSTREAKS: \(streakSummary)\n"
        }

        context += "\nGive ONE specific, actionable insight (2-3 sentences max). Connect data points the user wouldn't notice. For goals with a measurable target, watch the number: if a goal is BEHIND pace, call out the gap and what would close it. For habitual goals, judge by weekly cadence (the \"X of Y this week\" figure), not days since last touch — an off-day for a 3x/week goal is not a lapse. Be direct, not generic. No pleasantries."

        return context
    }

    /// C1 — decomposition prompt. Asks Claude to break ONE goal into a checkpoint
    /// chain appropriate to its horizon, returned as a JSON array of milestone
    /// items. Kept in sync with the `decompose` branch in the edge function.
    static func decomposePrompt(goal: Goal, horizon: GoalHorizon, existingMilestones: [Milestone]) -> String {
        var context = "You are an AI mentor inside ambidash, a life dashboard app. Break ONE long-range goal into a concrete checkpoint chain — the missing middle between the goal and a same-day action.\n\n"

        context += "GOAL: \(goal.title) (\(goal.domain.displayName))\n"
        context += "HORIZON: \(horizon.displayName) (\(horizon.timeframe))\n"
        if !goal.subtitle.isEmpty {
            context += "CONTEXT: \(goal.subtitle)\n"
        }
        context += measurableLine(for: goal)
        if goal.hasTarget { context += "\n" }
        context += habitualLine(for: goal)
        if goal.isHabitual { context += "\n" }

        // Shape guidance mirrors MilestoneGenerator.chainPeriods.
        let bands: String
        switch horizon {
        case .dream, .build: bands = "year, then quarter, then month"
        case .soon: bands = "quarter, then month, then week"
        case .now: bands = "month, then week"
        }
        context += "\nCHAIN SHAPE: For a \(horizon.displayName) goal, nest checkpoints from coarse to fine — \(bands). Each finer node should be a child of the coarser node it advances.\n"

        if !existingMilestones.isEmpty {
            context += "\nEXISTING CHECKPOINTS (do not duplicate; fill gaps or refine):\n"
            for m in existingMilestones.sorted(by: { $0.startDate < $1.startDate }) {
                context += "- [\(m.period.displayName)] \(m.title)\n"
            }
        }

        context += "\nRespond with ONLY a JSON array of checkpoint items. Each item: "
        context += "{\"title\": \"...\", \"detail\": \"...\", \"period\": \"year|quarter|month|week\", "
        context += "\"parent_index\": N or null, \"target_value\": N or null, \"unit\": \"...\" or null, "
        context += "\"weeks_from_now_start\": N, \"weeks_from_now_end\": N}\n"
        context += "Rules: period MUST be exactly one of year|quarter|month|week. parent_index references the zero-based position of an EARLIER item in this same array (the coarser checkpoint this one nests under), or null for a top-level node — this expresses the tree. weeks_from_now_start/weeks_from_now_end are integer week offsets from today defining the checkpoint window (start < end). Set target_value + unit only for measurable checkpoints; otherwise null. Keep the chain tight (typically 1 node per band, 2-4 items total). Make titles concrete and outcome-oriented, not generic."

        return context
    }

    static func planPrompt(goals: [Goal], snapshot: IntegrationSnapshot?, profile: UserProfile?, planContext: AIService.PlanContext = AIService.PlanContext()) -> String {
        // PLAN REWRITE — the plan is the user's REAL DAY, woven from three layers:
        // (1) fixed anchors, (2) daily routines, (3) goal-work in the free gaps.
        var context = "You are building this person's real day as a concrete, time-ordered plan they can just follow.\n\n"
        context += "The day has three layers, woven into ONE timeline:\n"
        context += "1) FIXED ANCHORS — wake, meals, work/class blocks, sleep. These are set; build around them, never move them.\n"
        context += "2) DAILY ROUTINES — their morning routine (skincare/oral care/no-phone), workout, cooking. Pull these straight from their preferences below.\n"
        context += "3) GOAL-WORK — concrete tasks toward their active goals, slotted ONLY into the free gaps between anchors.\n\n"
        context += "Every single line must read like a real instruction with a time or relative cue + a concrete action + a duration. Examples of the voice:\n"
        context += "  \"07:00 — No phone, make breakfast (20m)\"\n"
        context += "  \"Before 13:00 — Have lunch (30m)\"\n"
        context += "  \"After class — Gym, push day (45m)\"\n"
        context += "  \"20:00 — Cook dinner (40m)\"\n"
        context += "  \"Work block 14:00–14:50 — <specific goal task, e.g. draft section 2 of the thesis> (50m)\"\n"
        context += "BANNED: abstract filler like \"show up today\", \"fix sleep\", \"make progress\", \"work on yourself\". Every goal-work line names a SPECIFIC task.\n\n"

        if let profile {
            context += "USER: \(profile.name), age \(profile.age)\n"
            if let assessment = profile.coreAssessment {
                context += "Peak energy: \(assessment.peakEnergyTime)\n"
                context += "Focus style: \(assessment.cognitiveStyle)\n"
                context += "Overwhelm response: \(assessment.overwhelmResponse)\n"
            }
            if let pref = profile.workStylePreference {
                context += "Preferred format: \(pref.format.displayName)\n"
                context += "Max actions/day: \(pref.maxActionsPerDay)\n"
            }
        }

        // FOUNDATION — the user's daily-rhythm preferences, so the plan is built
        // around real anchors (wake/sleep, meals, work blocks, routines, workout)
        // rather than floating free. Empty when prefs haven't been set.
        context += preferencesContext(planContext.userPreferences)

        // PLAN REWRITE — the concrete fixed/routine skeleton + the explicit free
        // gaps, computed from the user's preferences, so the model fills the SAME
        // gaps the offline planner does. Empty when no prefs are set.
        context += DailyTimeline.promptSkeleton(from: planContext.userPreferences)

        context += "\nGOALS (most in need of attention first):\n"
        // Rank habitual goals by how far short of this week's cadence they are
        // (an off-day for a 3x/wk goal is NOT neglect); rank the rest by raw
        // neglect days. Habitual goals behind cadence sort ahead of on-track ones.
        let sorted = goals.filter(\.isActive).sorted { lhs, rhs in
            attentionScore(for: lhs) > attentionScore(for: rhs)
        }
        for goal in sorted {
            if goal.isHabitual {
                context += "- [id: \(goal.id.uuidString)] \(goal.title): priority \(goal.priority)"
            } else {
                context += "- [id: \(goal.id.uuidString)] \(goal.title): \(goal.neglectDays) days neglected, priority \(goal.priority)"
            }
            // PLAN REWRITE — the user's own goal detail makes the goal-work
            // concrete ("45 min push/pull/legs at campus gym"). Use it verbatim.
            let detail = goal.details.trimmingCharacters(in: .whitespaces)
            if !detail.isEmpty {
                context += " · detail: \(detail)"
            }
            context += measurableLine(for: goal)
            context += habitualLine(for: goal)
            context += "\n"
        }

        if let snap = snapshot {
            context += "\nTODAY'S STATE:\n"
            context += "- Rest: \(snap.restHint), \(snap.calendarFreeMinutes)min free\n"
        }

        // A2 / #8 — adaptive history + explicit user intent. Folding in what was
        // actually done/skipped (with reasons), the latest reflection, and the
        // user's postpone/focus choice lets the plan respond to reality.
        context += adaptiveContext(planContext)

        let maxGoalWork = profile?.workStylePreference?.maxActionsPerDay ?? 6
        context += "\nRespond with ONLY a JSON array covering the WHOLE day, time-ordered earliest→latest. Each item:\n"
        context += "{\"anchor_type\": \"fixed|routine|goal_work\", \"title\": \"...\", \"why\": \"...\", \"duration_minutes\": N, \"time_slot\": \"HH:MM\", \"schedule_cue\": \"...\", \"goal_id\": \"uuid-string\", \"amount\": N, \"metric\": \"unit\", \"cue_trigger\": \"...\", \"target_amount\": N, \"target_unit\": \"...\"}\n\n"
        context += "RULES:\n"
        context += "- Emit the FULL woven timeline: every fixed anchor and daily routine from the skeleton above, PLUS goal-work in the free gaps. Order strictly by time_slot.\n"
        context += "- \"anchor_type\": \"fixed\" for wake/meals/work-class/sleep; \"routine\" for morning routine / workout / cooking; \"goal_work\" for goal tasks.\n"
        context += "- \"time_slot\" is the start clock time \"HH:MM\" (24h). ALWAYS set it. \"schedule_cue\" is the human label when it's relative, e.g. \"Before 13:00\", \"After class\", \"By 23:30\"; leave it \"\" for a hard clock time.\n"
        context += "- The \"title\" is a clean instruction WITHOUT the time prefix (the app shows the time separately), e.g. \"No phone, make breakfast\", \"Gym — push day\", \"Cook dinner\", \"Draft section 2 of the thesis\". NEVER abstract: no \"show up\", no \"fix sleep\".\n"
        context += "- ONLY goal_work items set goal_id (exactly one UUID from the GOALS list; never invent IDs). Fixed and routine items MUST omit goal_id, amount, target_amount.\n"
        context += "- For a goal_work item on a measurable goal: set \"amount\" to the increment it adds (in the goal's unit) + \"metric\" to that unit. Where it's naturally quantifiable (reps/min/pages/words) also set \"target_amount\" + \"target_unit\". \"cue_trigger\" is its relative anchor (e.g. \"after lunch\").\n"
        context += "- At most \(maxGoalWork) goal_work items — keep the day focused. Prioritize goals BEHIND pace, then habitual goals short of weekly cadence, then neglected one-off goals. A habitual goal that has met its weekly cadence needs no action today; an off-day is NOT neglect. Adjust goal-work intensity to sleep quality.\n"
        context += "- If the user has set NO preferences (no skeleton above), still produce a concrete, time-ordered goal_work timeline across a sensible waking day (wake ~07:00, sleep ~23:00)."

        return context
    }

    /// FOUNDATION — renders the user's daily-rhythm preferences as a "YOUR DAY"
    /// block so the planner builds actions around real anchors. Empty string when
    /// no preferences are set, so the prompt is unchanged for that case. This pass
    /// only makes the data available; the next pass rewrites the instructions to
    /// fully exploit it.
    private static func preferencesContext(_ prefs: UserPreferences?) -> String {
        guard let p = prefs else { return "" }
        var out = "\nYOUR DAY (the user's real daily rhythm — build the plan around these anchors, don't fight them):\n"
        out += "- Awake \(p.wakeTime)–\(p.sleepTime)\n"
        out += "- Meals: breakfast \(p.breakfastTime), lunch \(p.lunchTime), dinner \(p.dinnerTime)\n"
        if !p.workBusyBlock.isEmpty {
            out += "- Busy block: \(p.workBusyBlock)\n"
        }
        if !p.morningRoutine.isEmpty {
            out += "- Morning routine: \(p.morningRoutine)\n"
        }
        if !p.eveningRoutine.isEmpty {
            out += "- Evening routine: \(p.eveningRoutine)\n"
        }
        if p.worksOut {
            let type = p.workoutType.isEmpty ? "workout" : p.workoutType
            out += "- Works out around \(p.workoutTime): \(type)\n"
        }
        out += "- Cooks own meals: \(p.cooksOwnMeals ? "yes" : "no")\n"
        out += "- Energy peak: \(p.energyPeak); prefers \(p.focusBlocksPerDay) focus block(s)/day\n"
        if !p.aboutMe.isEmpty {
            out += "- About them: \(p.aboutMe)\n"
        }
        if !p.hardConstraints.isEmpty {
            out += "- Hard constraints (never violate): \(p.hardConstraints)\n"
        }
        if !p.extraContext.isEmpty {
            out += "- Also: \(p.extraContext)\n"
        }
        return out
    }

    /// A2 / #8 — renders the adaptive-context block: recent done/skipped actions
    /// (with captured skip reasons), the latest reflection, and the user's
    /// postpone/focus intent. Empty string when no signal is available, so the
    /// prompt is unchanged for the cold-start case.
    private static func adaptiveContext(_ ctx: AIService.PlanContext) -> String {
        var out = ""

        if !ctx.recentDone.isEmpty {
            out += "\nRECENTLY COMPLETED (don't just repeat — build on momentum):\n"
            for action in ctx.recentDone.prefix(8) {
                out += "- \(action.title)\n"
            }
        }

        if !ctx.recentSkipped.isEmpty {
            out += "\nRECENTLY SKIPPED (adapt — don't blindly re-push what keeps getting deferred for the same reason):\n"
            for action in ctx.recentSkipped.prefix(8) {
                let reason = (action.skipReason?.isEmpty == false) ? " — reason: \(action.skipReason!)" : ""
                out += "- \(action.title)\(reason)\n"
            }
        }

        if let reflection = ctx.latestReflection {
            var bits: [String] = []
            if !reflection.mood.isEmpty { bits.append("mood: \(reflection.mood)") }
            if !reflection.blockers.isEmpty { bits.append("blockers: \(reflection.blockers.joined(separator: ", "))") }
            if !reflection.freeformText.isEmpty { bits.append("note: \(reflection.freeformText)") }
            if !bits.isEmpty {
                out += "\nLATEST REFLECTION (honor what they told you): \(bits.joined(separator: " · "))\n"
            }
        }

        if let postponing = ctx.postponingIntent, !postponing.isEmpty {
            if postponing.lowercased() == "neither" {
                out += "\nUSER INTENT: They said they are NOT postponing any of their top goals today — keep all of them in play.\n"
            } else {
                out += "\nUSER INTENT: The user said they are postponing \"\(postponing)\" today — DEPRIORITIZE that goal (drop it or give it the lightest possible touch) and reallocate the freed time to their other goals.\n"
            }
        }
        if let focus = ctx.focusIntent, !focus.isEmpty {
            out += "USER FOCUS: They want to focus on \"\(focus)\" — weight the plan toward it.\n"
        }

        return out
    }

    /// MENTOR REFOCUS — two-way reply prompt. The mentor now frames its reply in a
    /// FORWARD breakdown: what the user is doing TODAY, what they're working toward
    /// THIS WEEK, and roughly how much closer finishing today gets them to the goal.
    /// `todaysActions` are today's planned actions (for the "doing X, Y, Z" line).
    static func replyPrompt(userMessage: String, goals: [Goal], snapshot: IntegrationSnapshot?, todaysActions: [PlannedAction] = []) -> String {
        var context = "You are M., the AI mentor inside ambidash, a life dashboard app. The user has written you a letter. Reply as their mentor — warm but direct, never generic, never a list.\n\n"
        context += "Frame your reply FORWARD, not as a status report. Ground it in: what they're DOING today, what they're working toward THIS WEEK, and how today's work moves them closer to the goal. Be honest and approximate about the percentage — say \"about\" / \"roughly\".\n\n"

        context += forwardSummaryText(goals: goals, todaysActions: todaysActions)

        if let snap = snapshot {
            context += "\nTODAY'S DATA: Rest \(snap.restHint), \(snap.calendarFreeMinutes)min free\n"
        }

        context += "\nTHE USER WROTE:\n\"\(userMessage)\"\n"
        context += "\nWrite back in 2-4 sentences. Respond to what they actually said, then anchor them: today you're doing X; this week you're working toward Y; finishing today puts you roughly N% closer to <goal>. Be specific, never generic, no bullet lists. Sign off with \"— M.\" only if it feels natural."

        return context
    }

    /// MENTOR REFOCUS — the shared today → this-week → %-closer breakdown, used by
    /// both the reply prompt and the MentorView forward-summary card so the spoken
    /// framing and the on-screen framing stay identical. Pure text; safe with no
    /// milestones (each block degrades gracefully).
    static func forwardSummaryText(goals: [Goal], todaysActions: [PlannedAction]) -> String {
        let active = goals.filter(\.isActive)
        var out = ""

        // TODAY — the goal-work the user is actually doing today (skip anchors/routines).
        let goalWork = todaysActions.filter { $0.anchorKind == .goalWork }
        if !goalWork.isEmpty {
            let titles = goalWork.prefix(4).map(\.title).joined(separator: "; ")
            out += "TODAY YOU'RE DOING: \(titles)\n"
        }

        // THIS WEEK — the active week checkpoint(s) and their parent month focus.
        var weekLines: [String] = []
        for goal in active {
            if let week = activeMilestone(in: goal, period: .week) {
                let pct = Int((week.percentComplete * 100).rounded())
                weekLines.append("\(week.title) — \(pct)% done")
            }
        }
        if !weekLines.isEmpty {
            out += "THIS WEEK YOU'RE WORKING TOWARD:\n"
            for line in weekLines.prefix(4) { out += "- \(line)\n" }
        }

        // PROGRESS — for each goal in flight, how close after today.
        var progressLines: [String] = []
        for goal in active {
            if goal.hasTarget {
                let now = Int((goal.percentComplete * 100).rounded())
                progressLines.append("\(goal.title): about \(now)% complete; finishing today's work nudges that up")
            } else if goal.isHabitual {
                let logged = AdherenceFormat.loggedThisWeek(for: goal)
                let target = AdherenceFormat.target(for: goal)
                progressLines.append("\(goal.title): \(logged) of \(target) this week; today would make it \(min(logged + 1, target)) of \(target)")
            }
        }
        if !progressLines.isEmpty {
            out += "PROGRESS IF THEY FINISH TODAY:\n"
            for line in progressLines.prefix(4) { out += "- \(line)\n" }
        }

        if out.isEmpty {
            // No milestone/goal structure yet — give the mentor the bare goal list.
            out += "USER'S GOALS:\n"
            for goal in active {
                out += "- \(goal.title) (\(goal.domain.displayName)): \(goal.computedStatus.label)\(measurableLine(for: goal))\(habitualLine(for: goal))\n"
            }
        }
        return out
    }

    /// MENTOR REFOCUS — the goal's active milestone at `period` whose window
    /// contains now, searching the flat milestone list. nil when none is active.
    private static func activeMilestone(in goal: Goal, period: MilestonePeriod) -> Milestone? {
        (goal.milestones ?? [])
            .filter { $0.period == period && $0.isActiveNow }
            .sorted { $0.startDate > $1.startDate }
            .first
    }
}
