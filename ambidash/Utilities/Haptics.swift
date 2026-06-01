#if os(iOS)
import UIKit

enum Haptics {
    static func light() {
        MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func medium() {
        MainActor.assumeIsolated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func success() {
        MainActor.assumeIsolated {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func warning() {
        MainActor.assumeIsolated {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    static func error() {
        MainActor.assumeIsolated {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    static func selection() {
        MainActor.assumeIsolated {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
#else
// macOS has no haptic feedback APIs; provide silent no-op stubs so shared
// call sites compile and behave gracefully on the desktop.
enum Haptics {
    static func light() {}
    static func medium() {}
    static func success() {}
    static func warning() {}
    static func error() {}
    static func selection() {}
}
#endif
