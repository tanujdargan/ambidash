// ambidash/App/NotificationDelegate.swift
//
// The app's UNUserNotificationCenterDelegate (iOS-only). Wired via
// UIApplicationDelegateAdaptor in AmbidashApp. Before this, NO delegate existed,
// so the interactive GENTLE_CHECKIN actions were inert — categories alone do
// nothing without a delegate to receive the taps.
//
// Responsibilities:
//  • willPresent  → show gentle notifications as a banner + sound even in-app.
//  • didReceive   → route the action-first taps and record dismissal back-off:
//      - I_FEEL_BETTER → the disruption "restore my original plan" flow (TODO: the
//        DisruptionService is greenfield; for now deep-link Today + mark intent).
//      - MOVE_PLAN     → the re-plan-as-diff flow (same TODO; deep-link Today).
//      - JUST_ONE      → triage mode, collapse to the one next thing (same TODO).
//      - default dismiss → record a dismissal so a nagged reminder backs off.
//
// The greenfield disruption/triage destinations don't exist yet, so each action
// publishes a typed `PendingGentleAction` the app can observe and a Today
// deep-link, keeping the wiring real and the extension point obvious.
#if os(iOS)
import Foundation
import UIKit
import UserNotifications

/// A one-shot marker the UI layer can read on next foreground to run the routed
/// gentle-check-in action once the disruption/triage screens exist.
enum PendingGentleAction: String {
    case restorePlan        // "I feel better" → restore original plan
    case replan             // "Move my plan" → re-plan-as-diff
    case triage             // "Just one thing" → collapse to next single block

    static let defaultsKey = "pendingGentleAction"

    static func store(_ action: PendingGentleAction) {
        UserDefaults.standard.set(action.rawValue, forKey: defaultsKey)
    }

    /// Reads and clears the pending action (consume-once).
    static func take() -> PendingGentleAction? {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        return PendingGentleAction(rawValue: raw)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Posted with the resolved `DeepLink.tabIndex` so the app can switch tabs in
    /// response to a notification tap without coupling this delegate to SwiftUI.
    static let deepLinkNotification = Notification.Name("ambidash.notification.deepLink")

    func registerAsDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Foreground presentation: gentle notifications still surface as a calm banner
    // + sound (cheat-sheet §4) rather than being silently swallowed in-app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Tap / action handling.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let dismissKey = userInfo["dismissKey"] as? String

        switch response.actionIdentifier {
        case NotificationService.Action.iFeelBetter:
            // The user is back on track — they're engaging, so clear any back-off.
            if let key = dismissKey { NotificationService.resetDismissals(forKey: key) }
            PendingGentleAction.store(.restorePlan)
            routeDeepLink(userInfo, fallback: .today)

        case NotificationService.Action.movePlan:
            if let key = dismissKey { NotificationService.resetDismissals(forKey: key) }
            PendingGentleAction.store(.replan)
            routeDeepLink(userInfo, fallback: .today)

        case NotificationService.Action.justOne:
            if let key = dismissKey { NotificationService.resetDismissals(forKey: key) }
            PendingGentleAction.store(.triage)
            routeDeepLink(userInfo, fallback: .today)

        case NotificationService.Action.snooze:
            // Explicit "Later" — gentle re-offer shortly, no back-off penalty.
            NotificationService.scheduleGentleCheckin(after: 30 * 60)

        case UNNotificationDefaultActionIdentifier:
            // Tapped the notification body itself — engagement, reset back-off + route.
            if let key = dismissKey { NotificationService.resetDismissals(forKey: key) }
            routeDeepLink(userInfo, fallback: nil)

        case UNNotificationDismissActionIdentifier:
            // Swiped away — count it toward the dismissal back-off so a repeatedly
            // ignored reminder family goes quiet.
            if let key = dismissKey { NotificationService.recordDismissal(forKey: key) }

        default:
            break
        }

        completionHandler()
    }

    /// Resolves a stored deep link (or a fallback) and posts it for the app to act on.
    private func routeDeepLink(_ userInfo: [AnyHashable: Any], fallback: DeepLink?) {
        let link: DeepLink? = {
            if let raw = userInfo["deepLink"] as? String, let l = DeepLink(rawValue: raw) { return l }
            return fallback
        }()
        guard let link else { return }
        NotificationCenter.default.post(
            name: Self.deepLinkNotification,
            object: nil,
            userInfo: ["tabIndex": link.tabIndex]
        )
    }
}

/// Minimal UIApplicationDelegate that owns the notification delegate so the
/// interactive categories are live from launch.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        notificationDelegate.registerAsDelegate()
        NotificationService.registerCategories()
        return true
    }
}
#endif
