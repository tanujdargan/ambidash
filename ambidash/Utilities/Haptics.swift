#if os(iOS)
import UIKit

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
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
