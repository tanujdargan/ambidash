import Foundation
import AuthenticationServices

@MainActor
@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    private(set) var isAuthenticated = false
    private(set) var userId: String?
    private(set) var accessToken: String?

    private var supabaseURL: String {
        UserDefaults.standard.string(forKey: "supabase_url") ?? "http://127.0.0.1:54321"
    }

    private var supabaseAnonKey: String {
        UserDefaults.standard.string(forKey: "supabase_anon_key") ?? ""
    }

    func configure(url: String, anonKey: String) {
        UserDefaults.standard.set(url, forKey: "supabase_url")
        UserDefaults.standard.set(anonKey, forKey: "supabase_anon_key")
    }

    var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async -> Bool {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            return false
        }

        let body: [String: Any] = [
            "provider": "apple",
            "token": tokenString,
        ]

        guard let result = await postAuth("/auth/v1/token?grant_type=id_token", body: body) else {
            return false
        }

        accessToken = result["access_token"] as? String
        userId = (result["user"] as? [String: Any])?["id"] as? String
        isAuthenticated = accessToken != nil

        if isAuthenticated {
            saveSession()
        }

        return isAuthenticated
    }

    // MARK: - Email/password (for dev testing)

    func signUp(email: String, password: String) async -> Bool {
        let body: [String: Any] = ["email": email, "password": password]
        guard let result = await postAuth("/auth/v1/signup", body: body) else { return false }
        accessToken = result["access_token"] as? String
        userId = (result["user"] as? [String: Any])?["id"] as? String
        isAuthenticated = accessToken != nil
        if isAuthenticated { saveSession() }
        return isAuthenticated
    }

    func signIn(email: String, password: String) async -> Bool {
        let body: [String: Any] = ["email": email, "password": password]
        guard let result = await postAuth("/auth/v1/token?grant_type=password", body: body) else { return false }
        accessToken = result["access_token"] as? String
        userId = (result["user"] as? [String: Any])?["id"] as? String
        isAuthenticated = accessToken != nil
        if isAuthenticated { saveSession() }
        return isAuthenticated
    }

    func signOut() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "sb_access_token")
        UserDefaults.standard.removeObject(forKey: "sb_user_id")
    }

    func restoreSession() {
        accessToken = UserDefaults.standard.string(forKey: "sb_access_token")
        userId = UserDefaults.standard.string(forKey: "sb_user_id")
        isAuthenticated = accessToken != nil
    }

    private func saveSession() {
        UserDefaults.standard.set(accessToken, forKey: "sb_access_token")
        UserDefaults.standard.set(userId, forKey: "sb_user_id")
    }

    // MARK: - Database Operations

    func fetchGoals() async -> [[String: Any]]? {
        await get("/rest/v1/goals?select=*&order=priority.asc")
    }

    func upsertGoal(_ goal: [String: Any]) async -> Bool {
        await post("/rest/v1/goals", body: goal, upsert: true) != nil
    }

    func deleteGoal(id: String) async -> Bool {
        await delete("/rest/v1/goals?id=eq.\(id)")
    }

    func fetchProfile() async -> [String: Any]? {
        let results: [[String: Any]]? = await get("/rest/v1/profiles?select=*")
        return results?.first
    }

    func upsertProfile(_ profile: [String: Any]) async -> Bool {
        await post("/rest/v1/profiles", body: profile, upsert: true) != nil
    }

    func saveReflection(_ reflection: [String: Any]) async -> Bool {
        await post("/rest/v1/reflections", body: reflection) != nil
    }

    func savePlan(_ plan: [String: Any]) async -> Bool {
        await post("/rest/v1/daily_plans", body: plan) != nil
    }

    // MARK: - AI Mentor (via Edge Function)

    func callMentor(action: String, context: [String: Any]) async -> String? {
        let body: [String: Any] = ["action": action, "context": context]
        guard let url = URL(string: "\(supabaseURL)/functions/v1/ai-mentor") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(accessToken ?? supabaseAnonKey)", forHTTPHeaderField: "authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["text"] as? String
        } catch {
            ErrorLogger.log(error, context: "SupabaseService.callMentor")
            return nil
        }
    }

    // MARK: - HTTP Helpers

    private func postAuth(_ path: String, body: [String: Any]) async -> [String: Any]? {
        guard let url = URL(string: "\(supabaseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    private func get<T>(_ path: String) async -> T? {
        guard let url = URL(string: "\(supabaseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONSerialization.jsonObject(with: data) as? T
        } catch { return nil }
    }

    private func post(_ path: String, body: [String: Any], upsert: Bool = false) async -> [String: Any]? {
        guard let url = URL(string: "\(supabaseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "authorization")
        if upsert {
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "prefer")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    private func delete(_ path: String) async -> Bool {
        guard let url = URL(string: "\(supabaseURL)\(path)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 204
        } catch { return false }
    }
}
