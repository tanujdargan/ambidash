import SwiftUI

enum GoalStatus: String, Codable {
    case onTrack, needsAttention, slipping, paused

    var color: Color {
        switch self {
        case .onTrack: .green
        case .needsAttention: .orange
        // Non-punitive (principle #1): a "slipping" goal is not a failure, just one
        // that needs time. Use a muted grey, never red. Theme-bound surfaces should
        // prefer `ResolvedTheme.deferred`; this is the theme-unbound fallback.
        case .slipping: .gray
        case .paused: .gray
        }
    }

    var label: String {
        switch self {
        case .onTrack: "On Track"
        case .needsAttention: "Needs Attention"
        case .slipping: "Needs Time"
        case .paused: "Paused"
        }
    }
}
