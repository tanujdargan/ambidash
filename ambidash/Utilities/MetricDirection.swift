import SwiftUI

enum MetricDirection: String, CaseIterable, Codable, Identifiable {
    case increase, decrease

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .increase: "Increase"
        case .decrease: "Decrease"
        }
    }

    var icon: String {
        switch self {
        case .increase: "arrow.up.right"
        case .decrease: "arrow.down.right"
        }
    }
}
