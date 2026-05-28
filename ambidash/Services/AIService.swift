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

    static func generateInsight(goals: [Goal], snapshot: IntegrationSnapshot?, streakSummary: String) async throws -> String {
        // Try edge function first (API key stays server-side)
        if SupabaseService.shared.isAuthenticated {
            let context: [String: Any] = [
                "goals": goals.map { [
                    "title": $0.title, "domain": $0.domainRaw,
                    "neglect_days": $0.neglectDays, "streak": $0.streak?.currentCount ?? 0
                ] },
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

    static func generatePlanJSON(goals: [Goal], snapshot: IntegrationSnapshot?, profile: UserProfile?) async throws -> String {
        // Try edge function first
        if SupabaseService.shared.isAuthenticated {
            let context: [String: Any] = [
                "goals": goals.map { [
                    "title": $0.title, "domain": $0.domainRaw,
                    "neglect_days": $0.neglectDays, "streak": $0.streak?.currentCount ?? 0
                ] },
                "profile": profile.map { [
                    "name": $0.name, "age": $0.age,
                    "peak_energy": $0.coreAssessment?.peakEnergyTime ?? "",
                    "cognitive_style": $0.coreAssessment?.cognitiveStyle ?? ""
                ] } as Any,
            ]
            if let result = await SupabaseService.shared.callMentor(action: "plan", context: context) {
                return result
            }
        }
        // Fallback to direct API
        let prompt = MentorPromptBuilder.planPrompt(goals: goals, snapshot: snapshot, profile: profile)
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
