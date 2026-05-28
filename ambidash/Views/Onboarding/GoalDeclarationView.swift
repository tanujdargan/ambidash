import SwiftUI
import SwiftData

struct GoalDeclarationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var selectedDomains: Set<GoalDomain> = []
    @State private var showWorkStyle = false

    private var profile: UserProfile? { profiles.first }

    private let pillarInfo: [(domain: GoalDomain, examples: [String])] = [
        (.body, ["Fix sleep", "Compound lifts 3–4x/week", "Lean toned body", "Grooming locked in"]),
        (.mind, ["Honour dad's wish", "Control emotions", "Build self-confidence", "Reading habit", "Fix oversharing"]),
        (.craft, ["Crush Amazon internship", "Launch startup solo", "AI research", "Public speaking", "Canadian PR"]),
        (.people, ["Be more social", "Make real friends", "Build deliberate network", "Decide what kind of son to be"]),
        (.wealth, ["XEQT compounding", "Financial independence", "Buy the Porsche 911"]),
        (.adventure, ["Keep gaming", "Photography", "Tokyo trip", "Nordschleife lap", "Pilot license"]),
    ]

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STEP 04 / 06 · GOALS")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(t.muted)

                            Text("You said yes to all of these once. Which still matter?")
                                .font(.system(size: 24, weight: .regular, design: .serif))
                                .tracking(-0.2)
                                .lineSpacing(2)
                                .foregroundStyle(t.ink)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                        // Pillar cards
                        VStack(spacing: 10) {
                            ForEach(Array(pillarInfo.enumerated()), id: \.element.domain) { index, info in
                                let isSelected = selectedDomains.contains(info.domain)

                                Button {
                                    Haptics.selection()
                                    if isSelected {
                                        selectedDomains.remove(info.domain)
                                    } else {
                                        selectedDomains.insert(info.domain)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: info.domain.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(isSelected ? t.accent : t.muted)
                                                .frame(width: 24)

                                            Text(info.domain.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(t.ink)

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(t.accent)
                                            }
                                        }

                                        Text(info.examples.joined(separator: " · "))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(t.faint)
                                            .lineLimit(2)
                                    }
                                    .padding(14)
                                    .background(isSelected ? t.accent.opacity(0.08) : t.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? t.accent.opacity(0.4) : t.hair, lineWidth: isSelected ? 1 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                                .staggeredAppear(index: index)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                    .padding(.bottom, 24)
                }

                // Bottom buttons
                HStack(spacing: 10) {
                    Spacer()
                    PillButton(label: "Continue", primary: true) {
                        saveGoals()
                        showWorkStyle = true
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
                .opacity(selectedDomains.isEmpty ? 0.4 : 1)
                .disabled(selectedDomains.isEmpty)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showWorkStyle) {
            WorkStylePickerView()
        }
    }

    private func saveGoals() {
        guard let profile else { return }
        var priority = 1
        for domain in selectedDomains.sorted(by: { $0.displayName < $1.displayName }) {
            for template in GoalLibrary.starterGoals(for: domain) {
                let goal = Goal(title: template.title, domain: domain, priority: priority)
                goal.subtitle = template.subtitle
                goal.horizon = template.horizon
                goal.streak = Streak()
                profile.goals.append(goal)
                priority += 1
            }
        }
        try? modelContext.save()
    }
}
