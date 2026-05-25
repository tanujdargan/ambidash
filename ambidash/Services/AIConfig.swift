// ambidash/Services/AIConfig.swift
import Foundation

enum AIConfig {
    static var apiKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static func setApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")
    }

    static let model = "claude-sonnet-4-20250514"
    static let maxTokens = 1024
}
