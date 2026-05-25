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

                        Text("Pick as many as you want. You can always add or remove later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                                        .frame(width: 32)

                                    Text(domain.displayName)
                                        .font(.body)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(14)
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
                saveGoals()
                showWorkStyle = true
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDomains.isEmpty)
            .padding()
        }
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
