// ambidash/Services/AppLimitController.swift
import Foundation
import SwiftUI
#if os(iOS)
import FamilyControls
import ManagedSettings
#endif

/// App-blocking ("app limits") via Apple's Family Controls + Managed Settings.
///
/// HONEST CAVEATS:
/// - Family Controls is device-only. On the Simulator the authorization prompt
///   and the app picker don't really work, and shielding does nothing. Real
///   blocking has to be tested on a physical iPhone.
/// - The chosen apps are stored as opaque `ApplicationToken`s that are ONLY
///   valid on the device that picked them. They cannot sync across devices via
///   CloudKit, so this is stored locally per device on purpose.
@MainActor
@Observable
final class AppLimitController {
    static let shared = AppLimitController()

    enum AuthState {
        case notDetermined   // never asked
        case approved        // user granted Screen Time control
        case denied          // user said no
        case unavailable     // not iOS, or Simulator — can't do this here
    }

    private(set) var authState: AuthState = .notDetermined
    /// True when apps are currently being blocked.
    private(set) var isShielding = false

    private let selectionKey = "applimits.selection"
    private let shieldingKey = "applimits.shielding"

    #if os(iOS)
    private let store = ManagedSettingsStore()

    /// The apps/categories the user picked to block. Persisted locally.
    var selection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }

    /// How many apps + categories are picked (for display).
    var blockedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
    #else
    var blockedCount: Int { 0 }
    #endif

    private init() {
        #if os(iOS)
        loadSelection()
        isShielding = UserDefaults.standard.bool(forKey: shieldingKey)
        refreshAuthState()
        if isShielding { applyShield() }
        #else
        authState = .unavailable
        #endif
    }

    // MARK: - Authorization

    /// Ask iOS for permission to manage Screen Time. Device-only; on the
    /// Simulator this throws and we land in `.unavailable`.
    func requestAuthorization() async {
        #if os(iOS)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthState()
        } catch {
            // The Simulator (and a no-Screen-Time device) throws here.
            authState = .unavailable
        }
        #else
        authState = .unavailable
        #endif
    }

    #if os(iOS)
    private func refreshAuthState() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:     authState = .approved
        case .denied:       authState = .denied
        case .notDetermined: authState = .notDetermined
        @unknown default:   authState = .notDetermined
        }
    }
    #endif

    // MARK: - Shielding

    /// Start blocking the picked apps.
    func startBlocking() {
        #if os(iOS)
        guard blockedCount > 0 else { return }
        isShielding = true
        UserDefaults.standard.set(true, forKey: shieldingKey)
        applyShield()
        #endif
    }

    /// Stop blocking — clear the shield.
    func stopBlocking() {
        #if os(iOS)
        isShielding = false
        UserDefaults.standard.set(false, forKey: shieldingKey)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        #endif
    }

    #if os(iOS)
    private func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    // MARK: - Persistence

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: selectionKey)
        // If we're actively blocking, re-apply so a changed picks take effect.
        if isShielding { applyShield() }
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }
    #endif
}
