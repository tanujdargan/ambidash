// ambidash/Services/ScaffoldingService.swift
import Foundation

enum ScaffoldingService {
    enum Level: Int {
        case heavy = 3
        case moderate = 2
        case light = 1

        var displayName: String {
            switch self {
            case .heavy: "Heavy"
            case .moderate: "Moderate"
            case .light: "Light"
            }
        }

        var description: String {
            switch self {
            case .heavy: "Full daily plans with detailed reasoning. Proactive notifications."
            case .moderate: "Shorter plans, notifications only for drift. You're building habits."
            case .light: "Minimal intervention. Mentor speaks only when data shows problems."
            }
        }

        var maxNotificationsPerDay: Int {
            switch self {
            case .heavy: 5
            case .moderate: 3
            case .light: 1
            }
        }

        var showDetailedWhy: Bool {
            self == .heavy
        }

        var autoGeneratePlan: Bool {
            self != .light
        }
    }

    static func recommendedLevel(for profile: UserProfile) -> Level {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: profile.createdAt, to: .now).day ?? 0

        if daysSinceCreation < 28 { return .heavy }
        if daysSinceCreation < 90 { return .moderate }
        return .light
    }

    static func shouldUpdateLevel(for profile: UserProfile) -> Level? {
        let current = Level(rawValue: profile.scaffoldLevel) ?? .heavy
        let recommended = recommendedLevel(for: profile)
        if current != recommended { return recommended }
        return nil
    }

    static func currentLevel(for profile: UserProfile) -> Level {
        Level(rawValue: profile.scaffoldLevel) ?? .heavy
    }
}
