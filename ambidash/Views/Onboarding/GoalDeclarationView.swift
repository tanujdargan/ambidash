import SwiftUI
import SwiftData

struct GoalDeclarationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedDomains: Set<GoalDomain> = []
    @State private var showWorkStyle = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you want to work on?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AmbidashTheme.textPrimary)

                        Text("Pick as many as you want. You can always add or remove later.")
                            .font(.subheadline)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 10) {
                        ForEach(GoalDomain.allCases) { domain in
                            let isSelected = selectedDomains.contains(domain)

                            Button {
                                if isSelected {
                                    selectedDomains.remove(domain)
                                } else {
                                    selectedDomains.insert(domain)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: domain.icon)
                                        .font(.title3)
                                        .foregroundStyle(AmbidashTheme.accent)
                                        .frame(width: 32)

                                    Text(domain.displayName)
                                        .font(.body)
                                        .foregroundStyle(AmbidashTheme.textPrimary)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AmbidashTheme.accent)
                                    }
                                }
                                .padding(14)
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
                saveGoals()
                showWorkStyle = true
            }
            .disabled(selectedDomains.isEmpty)
            .padding()
        }
        .background(AmbidashTheme.bgBase)
        .navigationTitle("Your Goals")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showWorkStyle) {
            WorkStylePickerView()
        }
    }

    private func saveGoals() {
        guard let profile else { return }
        for (index, domain) in selectedDomains.sorted(by: { $0.displayName < $1.displayName }).enumerated() {
            let goal = Goal(title: domain.displayName, domain: domain, priority: index + 1)
            goal.streak = Streak()
            profile.goals.append(goal)
        }
    }
}
