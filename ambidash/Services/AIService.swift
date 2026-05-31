// ambidash/Services/AIService.swift
import Foundation

@MainActor
enum AIService {
    struct Message: Codable {
        let role: String
        let content: String
    }

    struct APIRequest: Codable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
    }

    struct APIResponse: Codable {
        let content: [ContentBlock]

        struct ContentBlock: Codable {
            let type: String
            let text: String?
        }
    }

    enum AIError: Error {
        case notConfigured
        case networkError(Error)
        case invalidResponse
        case apiError(String)
    }

    /// Per-goal context entry including the F2 measurable-target keys when the
    /// goal has a target. Non-target goals get only the base keys.
    private static func goalContext(_ goal: Goal, includeID: Bool) -> [String: Any] {
        var entry: [String: Any] = [
            "title": goal.title, "domain": goal.domainRaw,
            "neglect_days": goal.neglectDays, "streak": goal.streak?.currentCount ?? 0
        ]
        if includeID {
            entry["id"] = goal.id.uuidString
        }
        // PLAN REWRITE — the user's own goal detail makes goal-work concrete.
        let detail = goal.details.trimmingCharacters(in: .whitespaces)
        if !detail.isEmpty {
            entry["details"] = detail
        }
        if goal.hasTarget {
            let variance: String
            switch TargetMath.variance(goal) {
            case .ahead: variance = "ahead"
            case .onTrack: variance = "on_pace"
            case .behind: variance = "behind"
            }
            entry["target_value"] = goal.targetValue
            entry["current_value"] = goal.currentValue
            entry["baseline_value"] = goal.baselineValue
            entry["unit"] = goal.unit
            entry["direction"] = goal.directionRaw
            entry["percent_complete"] = Int((goal.percentComplete * 100).rounded())
            entry["variance_state"] = variance
            entry["expected_value"] = TargetMath.expectedValue(goal)
        }
        return entry
    }

    static func generateInsight(goals: [Goal], snapshot: IntegrationSnapshot?, streakSummary: String) async throws -> String {
        // Try edge function first (API key stays server-side)
        if SupabaseService.shared.isAuthenticated {
            let context: [String: Any] = [
                "goals": goals.map { goalContext($0, includeID: false) },
                "snapshot": snapshot.map { [
                    "sleep_hours": $0.sleepHours, "steps": $0.steps,
                    "screen_time_hours": $0.screenTimeHours
                ] } as Any,
            ]
            if let result = await SupabaseService.shared.callMentor(action: "insight", context: context) {
                return result
            }
        }
        // Fallback to direct API
        let prompt = MentorPromptBuilder.insightPrompt(goals: goals, snapshot: snapshot, streakSummary: streakSummary)
        return try await callAPI(prompt: prompt)
    }

    /// A2 / #8 — recent action history folded into the planner context so the AI
    /// adapts to what actually happened: what got done, what got skipped (and the
    /// captured reason), the user's latest reflection, and an explicit
    /// "postponing / focusing on" intent (from MorningBriefView). All optional so
    /// callers that don't have the signal pass nil and behaviour is unchanged.
    struct PlanContext {
        var recentDone: [PlannedAction] = []
        var recentSkipped: [PlannedAction] = []
        var latestReflection: Reflection? = nil
        /// The goal title the user said they're postponing this week, or "neither".
        var postponingIntent: String? = nil
        /// Free-text focus intent, if captured.
        var focusIntent: String? = nil
        /// FOUNDATION — the user's daily-rhythm preferences ("Your Day"), so the
        /// planner can build the day around real anchors (wake/sleep, meals, work
        /// blocks, routines, workout). Optional; nil when not yet set.
        var userPreferences: UserPreferences? = nil
    }

    static func generatePlanJSON(goals: [Goal], snapshot: IntegrationSnapshot?, profile: UserProfile?, planContext: PlanContext = PlanContext()) async throws -> String {
        // Try edge function first
        if SupabaseService.shared.isAuthenticated {
            var context: [String: Any] = [
                "goals": goals.map { goalContext($0, includeID: true) },
                "profile": profile.map { [
                    "name": $0.name, "age": $0.age,
                    "peak_energy": $0.coreAssessment?.peakEnergyTime ?? "",
                    "cognitive_style": $0.coreAssessment?.cognitiveStyle ?? ""
                ] } as Any,
            ]
            // A2 / #8 — adaptive history + user intent (write-only; kept in lockstep
            // with the edge function 'plan' branch and MentorPromptBuilder.planPrompt).
            context["recent_done_actions"] = planContext.recentDone.map { actionHistory($0) }
            context["recent_skipped_actions"] = planContext.recentSkipped.map { actionHistory($0) }
            if let reflection = planContext.latestReflection {
                context["latest_reflection"] = [
                    "mood": reflection.mood,
                    "blockers": reflection.blockers,
                    "text": reflection.freeformText,
                ]
            }
            if let postponing = planContext.postponingIntent, !postponing.isEmpty {
                context["postponed_goal_title"] = postponing
            }
            if let focus = planContext.focusIntent, !focus.isEmpty {
                context["focus_intent"] = focus
            }
            // FOUNDATION — make the user's daily-rhythm preferences available to
            // the edge function (write-only for now; the next pass rewrites the
            // server prompt to consume them, kept additive so it's harmless until
            // then).
            if let prefs = planContext.userPreferences {
                context["preferences"] = preferencesContext(prefs)
                // PLAN REWRITE — the concrete fixed/routine skeleton + free gaps so
                // the edge prompt builds the same woven timeline the client does.
                let skeleton = DailyTimeline.promptSkeleton(from: prefs)
                if !skeleton.isEmpty {
                    context["day_skeleton"] = skeleton
                }
            }
            if let result = await SupabaseService.shared.callMentor(action: "plan", context: context) {
                return result
            }
        }
        // Fallback to direct API
        let prompt = MentorPromptBuilder.planPrompt(goals: goals, snapshot: snapshot, profile: profile, planContext: planContext)
        return try await callAPI(prompt: prompt)
    }

    /// A2 / #8 — compact history entry for a settled action passed to the planner,
    /// including the captured skip reason so the AI can avoid re-pushing what the
    /// user keeps deferring for the same reason.
    private static func actionHistory(_ action: PlannedAction) -> [String: Any] {
        var entry: [String: Any] = [
            "title": action.title,
            "status": action.statusRaw,
        ]
        if let goalID = action.goalID { entry["goal_id"] = goalID.uuidString }
        if let reason = action.skipReason, !reason.isEmpty { entry["skip_reason"] = reason }
        return entry
    }

    /// FOUNDATION — compact dictionary of the user's daily-rhythm preferences for
    /// the edge-function context. Mirrors the fields the client prompt renders so
    /// server + client stay aligned when the server prompt is rewritten next pass.
    private static func preferencesContext(_ p: UserPreferences) -> [String: Any] {
        var entry: [String: Any] = [
            "wake_time": p.wakeTime,
            "sleep_time": p.sleepTime,
            "breakfast_time": p.breakfastTime,
            "lunch_time": p.lunchTime,
            "dinner_time": p.dinnerTime,
            "work_busy_block": p.workBusyBlock,
            "morning_routine": p.morningRoutine,
            "evening_routine": p.eveningRoutine,
            "works_out": p.worksOut,
            "workout_time": p.workoutTime,
            "workout_type": p.workoutType,
            "cooks_own_meals": p.cooksOwnMeals,
            "energy_peak": p.energyPeak,
            "focus_blocks_per_day": p.focusBlocksPerDay,
        ]
        if !p.aboutMe.isEmpty { entry["about_me"] = p.aboutMe }
        if !p.hardConstraints.isEmpty { entry["hard_constraints"] = p.hardConstraints }
        if !p.extraContext.isEmpty { entry["extra_context"] = p.extraContext }
        return entry
    }

    /// A2 / #8 — two-way mentor reply. Sends the user's written reply plus light
    /// goal context and asks the mentor to respond in 2-3 sentences. Reuses the
    /// 'insight' edge action (which logs role=mentor) so no new server branch is
    /// needed; falls back to the direct API with a tailored reply prompt.
    static func generateMentorReply(userMessage: String, goals: [Goal], snapshot: IntegrationSnapshot?, todaysActions: [PlannedAction] = []) async throws -> String {
        if SupabaseService.shared.isAuthenticated {
            var context: [String: Any] = [
                "goals": goals.map { goalContext($0, includeID: false) },
                "snapshot": snapshot.map { [
                    "sleep_hours": $0.sleepHours, "steps": $0.steps,
                    "screen_time_hours": $0.screenTimeHours
                ] } as Any,
                "user_message": userMessage,
            ]
            // MENTOR REFOCUS — pass the forward today → week → %-closer breakdown so
            // the edge reply uses the same framing as the direct-API path.
            let summary = MentorPromptBuilder.forwardSummaryText(goals: goals, todaysActions: todaysActions)
            if !summary.isEmpty {
                context["forward_summary"] = summary
            }
            if let result = await SupabaseService.shared.callMentor(action: "insight", context: context) {
                return result
            }
        }
        let prompt = MentorPromptBuilder.replyPrompt(userMessage: userMessage, goals: goals, snapshot: snapshot, todaysActions: todaysActions)
        return try await callAPI(prompt: prompt)
    }

    /// C1 — decompose ONE goal into a checkpoint chain. Returns the raw JSON
    /// array text (caller parses + materializes via MilestoneGenerator). Follows
    /// generatePlanJSON's dual-path: edge function first, direct Anthropic API
    /// fallback. Offline-skeleton fallback (MilestoneGenerator.defaultChain) is
    /// the view's responsibility when this throws.
    static func decomposeGoalJSON(goal: Goal, horizon: GoalHorizon) async throws -> String {
        // Try edge function first (API key stays server-side).
        if SupabaseService.shared.isAuthenticated {
            var goalEntry = goalContext(goal, includeID: true)
            goalEntry["horizon"] = horizon.rawValue
            goalEntry["subtitle"] = goal.subtitle
            let existing: [[String: Any]] = (goal.milestones ?? [])
                .sorted { $0.startDate < $1.startDate }
                .map { [
                    "title": $0.title,
                    "period": $0.periodRaw,
                ] }
            let context: [String: Any] = [
                "goal": goalEntry,
                "milestones": existing,
            ]
            if let result = await SupabaseService.shared.callMentor(action: "decompose", context: context) {
                return result
            }
        }
        // Fallback to direct API.
        let prompt = MentorPromptBuilder.decomposePrompt(
            goal: goal,
            horizon: horizon,
            existingMilestones: goal.milestones ?? []
        )
        return try await callAPI(prompt: prompt)
    }

    /// Suggest a gentle triage for ONE captured thought (capture inbox, BYOK tier).
    /// Returns a compact JSON object `{ "kind": "task|goal|note", "title": "…",
    /// "durationMinutes": Int }`. The captured text is untrusted user content and is
    /// placed in the message body, never used to build instructions. This is the
    /// BYOK fallback BELOW on-device Foundation Models; callers degrade to the local
    /// heuristic if it throws.
    static func triageCaptureJSON(text: String) async throws -> String {
        let prompt = """
        Triage a single captured thought for a calm, non-punitive personal \
        dashboard. Classify it as exactly one of: "task" (a small doable action), \
        "goal" (a longer-range aspiration), or "note" (an idea with no clear \
        action). Provide a short, kind restatement as "title". If it is a task, set \
        "durationMinutes" to an estimate, else 0. Never invent urgency.

        Respond with ONLY a JSON object and nothing else:
        {"kind":"task|goal|note","title":"<short title>","durationMinutes":<int>}

        Thought: \(text)
        """
        return try await callAPI(prompt: prompt)
    }

    private static func callAPI(prompt: String) async throws -> String {
        guard AIConfig.isConfigured else { throw AIError.notConfigured }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(AIConfig.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = APIRequest(
            model: AIConfig.model,
            max_tokens: AIConfig.maxTokens,
            messages: [Message(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            ErrorLogger.log(error, context: "AIService.callAPI")
            throw AIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            let apiError = AIError.apiError("HTTP \(httpResponse.statusCode): \(errorText)")
            ErrorLogger.log(apiError, context: "AIService.callAPI")
            throw apiError
        }

        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let text = apiResponse.content.first?.text else {
            throw AIError.invalidResponse
        }

        return text
    }
}
