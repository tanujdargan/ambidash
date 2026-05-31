import Foundation

enum DeepLink: String {
    case dashboard = "ambidash://dashboard"
    case today = "ambidash://today"
    case goals = "ambidash://goals"
    case reflect = "ambidash://reflect"
    case mentor = "ambidash://mentor"
    case settings = "ambidash://settings"
    /// CLOSING RITUAL — the gentle evening wrap-up. Lands on the dashboard, where the
    /// "Close the Day" component is reachable; the ritual is also available from the
    /// Reflect tab. Kept distinct from `.reflect` so the evening notification's intent
    /// reads clearly and a future direct-present hook can branch on it.
    case closingRitual = "ambidash://closing-ritual"

    var tabIndex: Int {
        switch self {
        case .dashboard: 0
        case .today: 1
        case .goals: 2
        case .reflect: 3
        case .mentor: 4
        case .settings: 0
        case .closingRitual: 0
        }
    }

    static func from(url: URL) -> DeepLink? {
        DeepLink(rawValue: url.absoluteString)
    }
}
