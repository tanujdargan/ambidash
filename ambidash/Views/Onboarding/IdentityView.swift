import SwiftUI
import SwiftData

struct IdentityView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var name = ""
    @State private var age = ""
    @State private var location = ""
    @State private var tagline = ""
    @State private var showAssessment = false

    private var profile: UserProfile? { profiles.first }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, trimmedName.count <= 50 else { return false }
        guard let ageInt = Int(age), ageInt >= 13, ageInt <= 120 else { return false }
        return true
    }

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Step indicator
                Text("STEP 01 / 06 · WHO")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(t.muted)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                // Heading
                Text("I want to know who you are, not what you do.")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .tracking(-0.2)
                    .lineSpacing(2)
                    .foregroundStyle(t.ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        UnderlineField(label: "Name", value: $name)
                        UnderlineField(label: "Age", value: $age, suffix: "yrs", keyboard: .numberPad)
                        UnderlineField(label: "Where you live", value: $location)
                        UnderlineField(label: "What you do, in three words", value: $tagline)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                    // Why I ask
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "Why I ask")
                        Text("Context shapes the questions I'll ask you later. None of this leaves the device unless you connect an integration.")
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(t.ink2)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 22)
                }

                // Bottom buttons
                HStack(spacing: 10) {
                    Spacer()
                    PillButton(label: "Continue", primary: true) {
                        saveProfile()
                        showAssessment = true
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
                .opacity(isValid ? 1 : 0.4)
                .disabled(!isValid)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showAssessment) {
            AssessmentFlowView()
        }
    }

    private func saveProfile() {
        if let existing = profile {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.age = Int(age) ?? 0
            existing.lifeStage = tagline
        } else {
            let p = UserProfile(name: name.trimmingCharacters(in: .whitespaces), age: Int(age) ?? 0)
            p.lifeStage = tagline
            modelContext.insert(p)
        }
        try? modelContext.save()
    }
}

private struct UnderlineField: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    @Binding var value: String
    var suffix: String? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(title: label)
                Spacer()
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
            TextField("", text: $value)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(t.ink)
                .keyboardType(keyboard)
                .autocorrectionDisabled()

            t.rule.frame(height: 1)
        }
    }
}
