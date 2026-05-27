import SwiftUI

struct LaunchScreen: View {
    @Environment(ThemeManager.self) private var tm
    @State private var appeared = false

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                // Instrument mark (matching welcome screen)
                ZStack {
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 52, height: 52)
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 36, height: 36)
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 20, height: 20)
                    Circle().fill(t.accent).frame(width: 5, height: 5)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

                Text("AMBIDASH")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(t.muted)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
