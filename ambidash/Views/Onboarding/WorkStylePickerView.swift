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

                        Text("You can change this anytime in settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

                                    Text(format.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Button {
                savePreference()
                showComplete = true
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFormat == nil)
            .padding()
        }
        .navigationTitle("Work Style")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
    }

    private func savePreference() {
        guard let profile, let format = selectedFormat else { return }
        let pref = WorkStylePreference(planFormat: format)
        profile.workStylePreference = pref
    }
}
