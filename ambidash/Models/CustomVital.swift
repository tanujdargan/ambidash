// ambidash/Models/CustomVital.swift
//
// v5 feat/v5-custom-vitals — user-defined trackable vitals. Distinct from the dimension-based
// `vitalsGrid` (which shows the six LifeDimensions): these are habits/metrics the user chooses to
// track over time (Sleep, Exercise, Hydration, Nutrition, Mood, Focus, Energy, or a fully custom
// one) with their own unit + daily target, each accumulating a per-day entry history.
//
// CloudKit-safe: all scalars defaulted, the entries relationship is optional + cascade, and the
// inverse lives on the child (VitalEntry.vital).
import Foundation
import SwiftData

/// A vital the user has chosen to track. `categoryRaw` resolves to a `VitalCategory` for the
/// starter defaults; `iconSymbol` / `unit` / `target` are editable so even a category vital can be
/// tuned (and a `.custom` one is defined entirely by the user).
@Model
final class CustomVital {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = "custom"
    var iconSymbol: String = "star"
    var unit: String = ""
    /// The daily target value (e.g. 8 glasses, 30 min). 0 = no target (just track).
    var target: Double = 0
    var sortIndex: Int = 0
    var isActive: Bool = true
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \VitalEntry.vital) var entries: [VitalEntry]? = nil

    init(name: String = "", category: VitalCategory = .custom, iconSymbol: String? = nil,
         unit: String? = nil, target: Double? = nil, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name.isEmpty ? category.defaultName : name
        self.categoryRaw = category.rawValue
        self.iconSymbol = iconSymbol ?? category.defaultIcon
        self.unit = unit ?? category.defaultUnit
        self.target = target ?? category.defaultTarget
        self.sortIndex = sortIndex
        self.isActive = true
        self.createdAt = .now
    }

    var category: VitalCategory { VitalCategory(rawValue: categoryRaw) ?? .custom }
}

/// One logged value for a vital at a point in time. The per-vital tracking history.
@Model
final class VitalEntry {
    var id: UUID = UUID()
    var value: Double = 0
    var date: Date = Date.now
    var note: String = ""

    var vital: CustomVital?

    init(value: Double = 0, date: Date = .now, note: String = "") {
        self.id = UUID()
        self.value = value
        self.date = date
        self.note = note
    }
}

/// The starter vital categories, each with sensible default icon/unit/target. `.custom` is the
/// fully user-defined option. Model-layer (no SwiftUI) so both targets compile it.
enum VitalCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case sleep
    case exercise
    case hydration
    case nutrition
    case mood
    case focus
    case energy
    case custom

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .sleep: return "Sleep"
        case .exercise: return "Exercise"
        case .hydration: return "Hydration"
        case .nutrition: return "Nutrition"
        case .mood: return "Mood"
        case .focus: return "Focus"
        case .energy: return "Energy"
        case .custom: return "New vital"
        }
    }

    var defaultIcon: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .exercise: return "figure.run"
        case .hydration: return "drop.fill"
        case .nutrition: return "fork.knife"
        case .mood: return "face.smiling"
        case .focus: return "brain.head.profile"
        case .energy: return "bolt.fill"
        case .custom: return "star.fill"
        }
    }

    var defaultUnit: String {
        switch self {
        case .sleep: return "hrs"
        case .exercise: return "min"
        case .hydration: return "glasses"
        case .nutrition: return "meals"
        case .mood: return "/5"
        case .focus: return "min"
        case .energy: return "/5"
        case .custom: return ""
        }
    }

    var defaultTarget: Double {
        switch self {
        case .sleep: return 8
        case .exercise: return 30
        case .hydration: return 8
        case .nutrition: return 3
        case .mood: return 4
        case .focus: return 120
        case .energy: return 4
        case .custom: return 0
        }
    }
}
