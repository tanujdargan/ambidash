import SwiftUI

struct ShimmerView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var phase: CGFloat = 0

    var body: some View {
        let t = tm.resolved
        RoundedRectangle(cornerRadius: 6)
            .fill(t.surface)
            .overlay(
                LinearGradient(
                    colors: [t.surface, t.hair, t.surface],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

struct ShimmerCard: View {
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 12) {
            ShimmerView().frame(height: 14).frame(maxWidth: 200)
            ShimmerView().frame(height: 10).frame(maxWidth: 280)
            ShimmerView().frame(height: 10).frame(maxWidth: 240)
        }
        .padding(18)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }
}
