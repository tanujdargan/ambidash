import SwiftUI
import SwiftData

struct WorkStylePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedFormat: PlanFormat?
    @State private var showComplete = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How should your daily plan look?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AmbidashTheme.textPrimary)

                        Text("You can change this anytime in settings.")
                            .font(.subheadline)
                            .foregroundStyle(AmbidashTheme.textSecondary)
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
                                        .foregroundStyle(AmbidashTheme.textPrimary)

                                    Text(format.description)
                                        .font(.subheadline)
                                        .foregroundStyle(AmbidashTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(isSelected ? AmbidashTheme.accent.opacity(0.15) : AmbidashTheme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                                        .stroke(isSelected ? AmbidashTheme.accent : AmbidashTheme.border, lineWidth: isSelected ? 1.5 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            AccentButton("Continue") {
                savePreference()
                showComplete = true
            }
            .disabled(selectedFormat == nil)
            .padding()
        }
        .background(AmbidashTheme.bgBase)
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
