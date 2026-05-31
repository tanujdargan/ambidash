import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum MotionPreference {
    @MainActor
    static var prefersReducedMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    @MainActor
    static func animation(_ animation: Animation = .easeOut(duration: 0.2)) -> Animation? {
        if prefersReducedMotion {
            return nil
        }
        return animation
    }
}
