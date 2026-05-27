import SwiftUI
import SwiftData

struct FirstLetterView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var showComplete = false

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("STEP 06 / 06 · FIRST LETTER")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(t.muted)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("We've only just met, so I'll keep this short.")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .lineSpacing(4)
                            .foregroundStyle(t.ink)

                        Text("You want a lean body and a sharp mind, a company, less feed and more conversation, money that gives you choices, a partner who is yours. You want all of it now.")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .lineSpacing(4)
                            .foregroundStyle(t.ink)

                        Text("I am not going to make you a list. I am going to ask you one question every morning, and a different one most evenings. I will tell you when you are drifting, and I will be quieter on the days you are doing well.")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .lineSpacing(4)
                            .foregroundStyle(t.ink)

                        Text("The shape of this work is patience.")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .lineSpacing(4)
                            .foregroundStyle(t.ink)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                }

                Spacer()

                HStack(spacing: 10) {
                    Spacer()
                    PillButton(label: "Enter your dashboard", primary: true) {
                        showComplete = true
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
    }
}
