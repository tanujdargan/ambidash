import SwiftUI

struct FocusGuardView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss

    let minutesToday: Int
    let openCount: Int

    @State private var selectedReason: String?

    private let reasons = [
        "A break — my brain needed one",
        "Bored, honestly",
        "Avoiding something I should be doing",
        "Looking for one specific thing",
        "I don't know",
    ]

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SHORT-FORM · INTERCEPTED")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(t.muted)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 28) {
                    // Circle gauge
                    ZStack {
                        Circle()
                            .stroke(t.hair, lineWidth: 1)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: min(1, Double(minutesToday) / 60.0))
                            .stroke(t.accent, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(minutesToday)")
                                .font(.system(size: 18, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(t.ink)
                            Text("MIN TODAY")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                    }

                    // Main question
                    VStack(spacing: 14) {
                        Text("You opened this app \(openCount) times today.")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .tracking(-0.3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(t.ink)

                        Text("What were you looking for?")
                            .font(.system(size: 18, design: .serif))
                            .italic()
                            .foregroundStyle(t.ink2)
                    }

                    // Reason buttons
                    VStack(spacing: 8) {
                        ForEach(reasons, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                Text(reason)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedReason == reason ? t.bg : t.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(selectedReason == reason ? t.ink : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedReason == reason ? .clear : t.hair, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                // Bottom buttons
                HStack(spacing: 10) {
                    GhostButton(label: "Open anyway · 5 min") {
                        dismiss()
                    }
                    PrimaryButton(label: "Close it") {
                        dismiss()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }
}
