// ambidash/Services/PremiumGateService.swift
import Foundation

@MainActor
enum PremiumGateService {
    private static let insightCountKey = "daily_insight_count"
    private static let planCountKey = "daily_plan_count"
    private static let lastResetKey = "daily_count_reset_date"

    static var isPremium: Bool {
        SubscriptionService.shared.isPremium
    }

    static func canGeneratePlan() -> Bool {
        if isPremium { return true }
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: planCountKey) < 1
    }

    static func canFetchInsight() -> Bool {
        if isPremium { return true }
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: insightCountKey) < 1
    }

    static func canUseHonestMirror() -> Bool {
        isPremium
    }

    static func canUseStrategicAdvisor() -> Bool {
        isPremium
    }

    static func recordPlanGeneration() {
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: planCountKey)
        UserDefaults.standard.set(count + 1, forKey: planCountKey)
    }

    static func recordInsightFetch() {
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: insightCountKey)
        UserDefaults.standard.set(count + 1, forKey: insightCountKey)
    }

    static var remainingPlans: Int {
        if isPremium { return .max }
        resetIfNewDay()
        return max(0, 1 - UserDefaults.standard.integer(forKey: planCountKey))
    }

    static var remainingInsights: Int {
        if isPremium { return .max }
        resetIfNewDay()
        return max(0, 1 - UserDefaults.standard.integer(forKey: insightCountKey))
    }

    private static func resetIfNewDay() {
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(lastReset) {
            UserDefaults.standard.set(0, forKey: insightCountKey)
            UserDefaults.standard.set(0, forKey: planCountKey)
            UserDefaults.standard.set(Date.now, forKey: lastResetKey)
        }
    }
}
