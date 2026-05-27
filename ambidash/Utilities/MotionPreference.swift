import SwiftUI

enum MotionPreference {
    @MainActor
    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    @MainActor
    static func animation(_ animation: Animation = .easeOut(duration: 0.2)) -> Animation? {
        if UIAccessibility.isReduceMotionEnabled {
            return nil
        }
        return animation
    }
}
