// ambidash/Services/NotionService.swift
import Foundation

@MainActor
final class NotionService {
    static let shared = NotionService()

    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "notion_access_token")
    }

    var isConnected: Bool {
        accessToken != nil
    }

    func setAccessToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "notion_access_token")
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: "notion_access_token")
    }

    func fetchRecentActivity() async -> NotionActivity {
        guard let token = accessToken else { return NotionActivity() }

        let url = URL(string: "https://api.notion.com/v1/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        let body: [String: Any] = [
            "sort": [
                "direction": "descending",
                "timestamp": "last_edited_time"
            ],
            "page_size": 10
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return NotionActivity()
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []

            let today = Calendar.current.startOfDay(for: .now)
            var todayEdits = 0
            var recentTitles: [String] = []

            for result in results {
                if let lastEdited = result["last_edited_time"] as? String {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: lastEdited), date >= today {
                        todayEdits += 1
                    }
                }

                if let properties = result["properties"] as? [String: Any] {
                    for (_, prop) in properties {
                        if let propDict = prop as? [String: Any],
                           let title = propDict["title"] as? [[String: Any]],
                           let text = title.first?["plain_text"] as? String {
                            recentTitles.append(text)
                        }
                    }
                }
            }

            return NotionActivity(
                pagesEditedToday: todayEdits,
                recentPageTitles: Array(recentTitles.prefix(5)),
                totalRecentPages: results.count
            )
        } catch {
            return NotionActivity()
        }
    }
}

struct NotionActivity {
    var pagesEditedToday: Int = 0
    var recentPageTitles: [String] = []
    var totalRecentPages: Int = 0
}
