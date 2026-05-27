import Foundation

enum DeepLink: String {
    case dashboard = "ambidash://dashboard"
    case today = "ambidash://today"
    case goals = "ambidash://goals"
    case reflect = "ambidash://reflect"
    case mentor = "ambidash://mentor"
    case settings = "ambidash://settings"

    var tabIndex: Int {
        switch self {
        case .dashboard: 0
        case .today: 1
        case .goals: 2
        case .reflect: 3
        case .mentor: 4
        case .settings: 0
        }
    }

    static func from(url: URL) -> DeepLink? {
        DeepLink(rawValue: url.absoluteString)
    }
}
