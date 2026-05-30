import Foundation
import SwiftData

/// Imports goals from a user-supplied JSON file so the app never ships hardcoded
/// goals. Mirrors DataExportService's "goals" shape, so an exported file (or a
/// hand-written one) round-trips back in.
@MainActor
enum GoalImportService {
    struct ImportSummary {
        let imported: Int
        let skipped: Int
        let error: String?
    }

    /// Accepts either `{ "goals": [ {…} ] }` or a bare top-level array `[ {…} ]`.
    /// Per goal, only `title` is required; `domain` defaults to body and `horizon`
    /// to now. Optional `type` (habit/recurring/project/milestone/accumulation) and
    /// `times_per_week` are applied when present. Goals whose title already exists
    /// (case-insensitive) are skipped, so re-importing is safe.
    static func importGoals(from data: Data, context: ModelContext, profile: UserProfile?) -> ImportSummary {
        let parsed = try? JSONSerialization.jsonObject(with: data)
        let rows: [[String: Any]]
        if let obj = parsed as? [String: Any], let arr = obj["goals"] as? [[String: Any]] {
            rows = arr
        } else if let arr = parsed as? [[String: Any]] {
            rows = arr
        } else {
            return ImportSummary(imported: 0, skipped: 0,
                error: "Couldn't read this file. Expected JSON like { \"goals\": [ { \"title\": \"…\", \"domain\": \"body\" } ] }.")
        }

        // Ensure a profile exists to attach the goals to.
        let targetProfile: UserProfile
        if let profile {
            targetProfile = profile
        } else {
            targetProfile = UserProfile(name: "", age: 0)
            context.insert(targetProfile)
        }

        let existingTitles = Set((targetProfile.goals ?? []).map { $0.title.lowercased() })
        var priority = ((targetProfile.goals ?? []).map(\.priority).max() ?? 0) + 1
        var imported = 0
        var skipped = 0

        for row in rows {
            guard let rawTitle = row["title"] as? String else { skipped += 1; continue }
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !existingTitles.contains(title.lowercased()) else { skipped += 1; continue }

            let domain = GoalDomain(rawValue: (row["domain"] as? String) ?? "") ?? .body
            let goal = Goal(title: title, domain: domain, priority: priority)
            goal.subtitle = (row["subtitle"] as? String) ?? ""
            if let h = row["horizon"] as? String, GoalHorizon(rawValue: h) != nil {
                goal.horizonRaw = h
            }
            if let typeRaw = row["type"] as? String, GoalType(rawValue: typeRaw) != nil {
                goal.goalTypeRaw = typeRaw
            }
            if let tpw = row["times_per_week"] as? Int {
                goal.timesPerWeek = tpw
            }

            let streak = Streak()
            context.insert(streak)
            goal.streak = streak
            goal.profile = targetProfile
            context.insert(goal)

            priority += 1
            imported += 1
        }

        do {
            try context.save()
            return ImportSummary(imported: imported, skipped: skipped, error: nil)
        } catch {
            return ImportSummary(imported: imported, skipped: skipped,
                error: "Imported \(imported) but failed to save: \(error.localizedDescription)")
        }
    }
}
