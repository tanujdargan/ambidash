// ambidash/Services/ObsidianService.swift
import Foundation

@MainActor
final class ObsidianService {
    static let shared = ObsidianService()

    private var vaultURL: URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: "obsidian_vault_bookmark") else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    }

    var isConnected: Bool {
        vaultURL != nil
    }

    func setVaultURL(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .minimalBookmark) {
            UserDefaults.standard.set(bookmark, forKey: "obsidian_vault_bookmark")
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: "obsidian_vault_bookmark")
    }

    func fetchVaultActivity() async -> ObsidianActivity {
        guard let vaultURL else { return ObsidianActivity() }

        return await Task.detached(priority: .userInitiated) {
            let accessing = vaultURL.startAccessingSecurityScopedResource()
            defer { if accessing { vaultURL.stopAccessingSecurityScopedResource() } }

            let fm = FileManager.default
            let today = Calendar.current.startOfDay(for: .now)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!

            var totalNotes = 0
            var todayModified = 0
            var weekModified = 0
            var recentTitles: [String] = []

            guard let enumerator = fm.enumerator(
                at: vaultURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return ObsidianActivity() }

            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension == "md" else { continue }
                totalNotes += 1

                if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modified = values.contentModificationDate {
                    if modified >= today {
                        todayModified += 1
                        recentTitles.append(fileURL.deletingPathExtension().lastPathComponent)
                    } else if modified >= weekAgo {
                        weekModified += 1
                    }
                }
            }

            return ObsidianActivity(
                totalNotes: totalNotes,
                notesModifiedToday: todayModified,
                notesModifiedThisWeek: weekModified + todayModified,
                recentNoteTitles: Array(recentTitles.prefix(5))
            )
        }.value
    }
}

struct ObsidianActivity {
    var totalNotes: Int = 0
    var notesModifiedToday: Int = 0
    var notesModifiedThisWeek: Int = 0
    var recentNoteTitles: [String] = []
}
