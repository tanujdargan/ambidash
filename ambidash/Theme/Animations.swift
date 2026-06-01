import SwiftUI

extension Animation {
    static let ambidashSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let ambidashSnap = Animation.spring(response: 0.25, dampingFraction: 0.9)
    static let ambidashSlow = Animation.easeOut(duration: 0.4)
}

struct StaggeredAppear: ViewModifier {
    let index: Int
    let total: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            // Honor Reduce Motion: skip the slide entirely so nothing auto-animates.
            .offset(y: (appeared || MotionPreference.prefersReducedMotion) ? 0 : 12)
            .task {
                guard !appeared else { return }
                // When Reduce Motion is on, snap to the resting state with no slide.
                guard !MotionPreference.prefersReducedMotion else {
                    appeared = true
                    return
                }
                let delay = Double(index) * 0.04
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(MotionPreference.animation(.ambidashSpring)) {
                    appeared = true
                }
            }
    }
}

struct ScalePress: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.ambidashSnap, value: isPressed)
            // A non-zero activation threshold is essential: a 0-distance drag gesture
            // would claim the touch immediately and run simultaneously with the parent
            // ScrollView's pan, so the ScrollView would never receive a drag started
            // over a card — the board would only scroll from empty gaps. With an 8pt
            // minimum, a vertical pan is yielded to the ScrollView (scroll wins) and
            // the press-scale only fires for near-stationary touches.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct FadeSlideIn: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            // Honor Reduce Motion: skip the slide entirely so nothing auto-animates.
            .offset(y: (appeared || MotionPreference.prefersReducedMotion) ? 0 : 20)
            .task {
                guard !appeared else { return }
                // When Reduce Motion is on, snap to the resting state with no slide.
                guard !MotionPreference.prefersReducedMotion else {
                    appeared = true
                    return
                }
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                withAnimation(MotionPreference.animation(.ambidashSlow)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, total: Int = 10) -> some View {
        modifier(StaggeredAppear(index: index, total: total))
    }

    func scaleOnPress() -> some View {
        modifier(ScalePress())
    }

    func fadeSlideIn(delay: Double = 0) -> some View {
        modifier(FadeSlideIn(delay: delay))
    }
}
