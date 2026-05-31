import Foundation
import SwiftData

/// ENERGY / spoons (design principle #6) — a tiny, <2-second, NON-PUNITIVE energy
/// check-in. The user taps how much they have right now (1–5); that's it. This is
/// the backbone for humane re-prioritization: planning spends a finite daily energy
/// budget, and the disruption / "your day changed" flow reads recent energy to
/// collapse to one doable thing when the user is low.
///
/// There is NO "good" or "bad" level. A 1 is information, not a failure. The picker
/// never guilts, never asks "why", and the note is always optional.
///
/// CloudKit-safe (additive-only): every scalar is defaulted (level defaults to a
/// neutral 3), there are no relationships, and nothing here can break an older
/// client. Registered in BOTH ModelContainers (AmbidashApp.swift +
/// AmbidashMacApp.swift).
///
/// PRIVACY: energy/mood is sensitive personal data. It lives ONLY in the user's
/// private SwiftData/iCloud store — never logged, never shared except as opted-in
/// aggregates.
@Model
final class EnergyCheckin: Identifiable {
    var id: UUID = UUID()

    /// When the user checked in.
    var date: Date = Date()

    /// The reported energy, 1 (empty) … 5 (full). Defaults to a neutral 3 so a
    /// stray/auto record reads as "middle", never as a low/failure.
    var level: Int = 3

    /// Optional free note ("slept badly", "post-gym buzz"). Never required, never
    /// prompted for.
    var note: String = ""

    init(
        id: UUID = UUID(),
        date: Date = .now,
        level: Int = 3,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.level = max(1, min(5, level))
        self.note = note
    }

    /// The level clamped into the valid 1…5 range, for any older/garbage value.
    var clampedLevel: Int { max(1, min(5, level)) }
}

// MARK: - Energy level presentation

/// Calm, non-numeric presentation for an energy level. Kept here (model layer, no
/// SwiftUI) so both targets and any service can share the vocabulary. The picker UI
/// maps these to gentle icons/colors via the theme — NEVER red for a low level.
enum EnergyLevel: Int, CaseIterable, Identifiable {
    case empty = 1
    case low = 2
    case okay = 3
    case good = 4
    case full = 5

    var id: Int { rawValue }

    /// Resolve an arbitrary stored Int to a level (clamped), so the UI never crashes
    /// on an out-of-range/legacy value.
    static func resolve(_ raw: Int) -> EnergyLevel {
        EnergyLevel(rawValue: max(1, min(5, raw))) ?? .okay
    }

    /// Short, dignified label. No "bad"/"good" moralizing on the low end.
    var label: String {
        switch self {
        case .empty: return "Running on empty"
        case .low: return "Low"
        case .okay: return "Okay"
        case .good: return "Good"
        case .full: return "Full tank"
        }
    }

    /// One-word label for the compact picker.
    var shortLabel: String {
        switch self {
        case .empty: return "Empty"
        case .low: return "Low"
        case .okay: return "Okay"
        case .good: return "Good"
        case .full: return "Full"
        }
    }

    /// An SF Symbol that reads as a "battery / spoon" fill without judgment.
    var symbol: String {
        switch self {
        case .empty: return "battery.0percent"
        case .low: return "battery.25percent"
        case .okay: return "battery.50percent"
        case .good: return "battery.75percent"
        case .full: return "battery.100percent"
        }
    }
}
