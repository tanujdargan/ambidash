import SwiftUI

enum GoalStatus: String, Codable {
    case onTrack, needsAttention, slipping, paused

    var color: Color {
        switch self {
        case .onTrack: .green
        case .needsAttention: .orange
        case .slipping: .red
        case .paused: .gray
        }
    }

    var label: String {
        switch self {
        case .onTrack: "On Track"
        case .needsAttention: "Needs Attention"
        case .slipping: "Slipping"
        case .paused: "Paused"
        }
    }
}
