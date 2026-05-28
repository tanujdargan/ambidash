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
            .offset(y: appeared ? 0 : 12)
            .task {
                guard !appeared else { return }
                let delay = Double(index) * 0.04
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.ambidashSpring) {
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
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
            .offset(y: appeared ? 0 : 20)
            .task {
                guard !appeared else { return }
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                withAnimation(.ambidashSlow) {
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
