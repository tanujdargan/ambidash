import SwiftUI
import SwiftData

struct GoalDeclarationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var selectedDomains: Set<GoalDomain> = Set(GoalDomain.allCases)
    @State private var showWorkStyle = false

    private var profile: UserProfile? { profiles.first }

    private let pillarInfo: [(domain: GoalDomain, examples: [String])] = [
        (.body, ["Sleep", "Training", "Nutrition", "Energy"]),
        (.mind, ["Focus", "Emotions", "Learning", "Reflection"]),
        (.craft, ["Career", "Skills", "Projects", "Craft"]),
        (.people, ["Friends", "Family", "Network", "Belonging"]),
        (.wealth, ["Saving", "Investing", "Financial freedom"]),
        (.adventure, ["Travel", "Hobbies", "Experiences", "Play"]),
    ]

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STEP 04 / 06 · GOALS")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(t.muted)

                            Text("Which areas of life matter most right now?")
                                .font(.system(size: 24, weight: .regular, design: .serif))
                                .tracking(-0.2)
                                .lineSpacing(2)
                                .foregroundStyle(t.ink)

                            Text("Just to orient you — you'll name your actual goals next. Nothing here is locked in.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(t.muted)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

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

                HStack(spacing: 10) {
                    Spacer()
                    PillButton(label: "Continue", primary: true) {
                        saveGoals()
                        showWorkStyle = true
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showWorkStyle) {
            WorkStylePickerView()
        }
    }

    private func saveGoals() {
        // Goals are no longer auto-seeded from a hardcoded library — the user
        // adds their own (or they sync in from iCloud). Just ensure a profile
        // exists so the rest of onboarding has something to attach to.
        guard profile == nil else { return }
        let targetProfile = UserProfile(name: "", age: 0)
        modelContext.insert(targetProfile)
        do {
            try modelContext.save()
        } catch {
            ErrorLogger.log(error, context: "GoalDeclarationView.saveGoals")
        }
    }
}
