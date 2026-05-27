import SwiftUI

enum GoalHorizon: String, CaseIterable, Codable, Identifiable {
    case now, soon, build, dream

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .now: "Now"
        case .soon: "Soon"
        case .build: "Build"
        case .dream: "Dream"
        }
    }

    var timeframe: String {
        switch self {
        case .now: "0–3 months"
        case .soon: "3–12 months"
        case .build: "1–3 years"
        case .dream: "3–10 years"
        }
    }

    var dotColor: Color {
        switch self {
        case .now: Color(hex: 0x1D9E75)
        case .soon: Color(hex: 0xEF9F27)
        case .build: Color(hex: 0x378ADD)
        case .dream: Color(hex: 0x7F77DD)
        }
    }
}
