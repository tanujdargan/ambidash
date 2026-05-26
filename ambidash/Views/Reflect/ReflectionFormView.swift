import SwiftUI
import SwiftData

struct ReflectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood = ""
    @State private var selectedBlockers: Set<String> = []
    @State private var freeformText = ""
    @State private var saved = false

    let existingReflection: Reflection?

    private let moods = ["Crushed it", "Decent", "Meh", "Bad day"]
    private let blockers = ["Procrastination", "Low energy", "Unexpected events", "Anxiety", "Nothing"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you feel about today?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AmbidashTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(moods, id: \.self) { mood in
                            let isSelected = selectedMood == mood
                            Button(mood) {
                                selectedMood = mood
                            }
                            .font(.caption)
                            .foregroundStyle(isSelected ? AmbidashTheme.accent : AmbidashTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? AmbidashTheme.accent.opacity(0.2) : AmbidashTheme.bgElevated)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? AmbidashTheme.accent : Color.clear, lineWidth: 1))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What got in the way?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AmbidashTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(blockers, id: \.self) { blocker in
                            let isSelected = selectedBlockers.contains(blocker)
                            Button(blocker) {
                                if isSelected { selectedBlockers.remove(blocker) }
                                else { selectedBlockers.insert(blocker) }
                            }
                            .font(.caption)
                            .foregroundStyle(isSelected ? AmbidashTheme.accent : AmbidashTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? AmbidashTheme.accent.opacity(0.2) : AmbidashTheme.bgElevated)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? AmbidashTheme.accent : Color.clear, lineWidth: 1))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Anything else? (optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AmbidashTheme.textPrimary)

                TextField("Free-form thoughts...", text: $freeformText, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(AmbidashTheme.textPrimary)
                    .padding(12)
                    .background(AmbidashTheme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
            }

            AccentButton(saved ? "Saved" : "Save Reflection") {
                saveReflection()
            }
            .disabled(selectedMood.isEmpty || saved)
        }
        .onAppear {
            if let r = existingReflection {
                selectedMood = r.mood
                selectedBlockers = Set(r.blockers)
                freeformText = r.freeformText
                saved = true
            }
        }
    }

    private func saveReflection() {
        if let existing = existingReflection {
            existing.mood = selectedMood
            existing.blockers = Array(selectedBlockers)
            existing.freeformText = freeformText
        } else {
            let reflection = Reflection()
            reflection.mood = selectedMood
            reflection.blockers = Array(selectedBlockers)
            reflection.freeformText = freeformText
            modelContext.insert(reflection)
        }
        try? modelContext.save()
        saved = true
    }
}
