import SwiftUI
import SwiftData

struct WorkStylePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var selectedFormat: PlanFormat?
    @State private var showComplete = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How should your daily plan look?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(t.ink)

                        Text("You can change this anytime in settings.")
                            .font(.subheadline)
                            .foregroundStyle(t.muted)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        ForEach(PlanFormat.allCases) { format in
                            let isSelected = selectedFormat == format

                            Button {
                                selectedFormat = format
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(format.displayName)
                                        .font(.headline)
                                        .foregroundStyle(t.ink)

                                    Text(format.description)
                                        .font(.subheadline)
                                        .foregroundStyle(t.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(isSelected ? t.accent.opacity(0.15) : t.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? t.accent : t.hair, lineWidth: isSelected ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            AccentButton(label: "Continue") {
                savePreference()
                showComplete = true
            }
            .disabled(selectedFormat == nil)
            .padding()
        }
        .background(t.bg)
        .navigationTitle("Work Style")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            IntegrationSetupView()
        }
    }

    private func savePreference() {
        guard let profile, let format = selectedFormat else { return }
        let pref = WorkStylePreference(planFormat: format)
        profile.workStylePreference = pref
    }
}
