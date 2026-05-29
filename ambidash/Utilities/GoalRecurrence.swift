import SwiftUI

/// The recurrence rule for a goal's expected activity. String-raw enum backing
/// `Goal.recurrenceRaw`, mirroring `GoalHorizon`. `.none` means no fixed cadence.
enum GoalRecurrence: String, CaseIterable, Codable, Identifiable {
    case none, daily, weekly, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "No schedule"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .none: "circle.dashed"
        case .daily: "sun.max.fill"
        case .weekly: "calendar"
        case .custom: "slider.horizontal.3"
        }
    }
}
