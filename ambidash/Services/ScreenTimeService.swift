// ambidash/Services/ScreenTimeService.swift
import Foundation

@MainActor
final class ScreenTimeService {
    static let shared = ScreenTimeService()

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOS 16.0, *) {
            return true
        }
        return false
        #endif
    }

    var isAuthorized: Bool {
        UserDefaults.standard.bool(forKey: "screentime_authorized")
    }

    func requestAuthorization() async -> Bool {
        // Family Controls authorization requires Apple entitlement approval
        // Placeholder until entitlement is granted
        UserDefaults.standard.set(true, forKey: "screentime_authorized")
        return true
    }

    func fetchTodayScreenTime() async -> ScreenTimeData {
        // DeviceActivity reports are only available via the app extension
        // The extension writes data to a shared App Group container
        // This reads from that shared container
        let defaults = UserDefaults(suiteName: "group.com.ambidash.app")

        return ScreenTimeData(
            totalHours: defaults?.double(forKey: "screen_total_hours") ?? 0,
            socialHours: defaults?.double(forKey: "screen_social_hours") ?? 0,
            entertainmentHours: defaults?.double(forKey: "screen_entertainment_hours") ?? 0,
            productivityHours: defaults?.double(forKey: "screen_productivity_hours") ?? 0,
            pickups: defaults?.integer(forKey: "screen_pickups") ?? 0
        )
    }
}

struct ScreenTimeData {
    var totalHours: Double = 0
    var socialHours: Double = 0
    var entertainmentHours: Double = 0
    var productivityHours: Double = 0
    var pickups: Int = 0

    var categories: [String: Double] {
        [
            "Social": socialHours,
            "Entertainment": entertainmentHours,
            "Productivity": productivityHours,
        ].filter { $0.value > 0 }
    }
}
