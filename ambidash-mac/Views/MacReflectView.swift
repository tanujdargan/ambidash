import SwiftUI
import SwiftData

/// Desktop Reflect: write a freeform daily reflection and browse past entries.
/// Reflections are stored in the shared SwiftData store and sync via CloudKit.
struct MacReflectView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context

    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]

    @State private var draft = ""
    @State private var mood = ""

    var body: some View {
        let theme = tm.resolved
        MacScreen("Reflect", subtitle: "Capture how today went") {
            EmptyView()
        } content: {
            MacCard("New Reflection") {
                LabeledField("Mood") {
                    TextField("e.g. focused, tired, hopeful", text: $mood)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Reflection") {
                    TextEditor(text: $draft)
                        .font(theme.body(14))
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(theme.hair, lineWidth: 1)
                        )
                }
                HStack {
                    Spacer()
                    Button("Save Reflection") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            MacCard("History") {
                if reflections.isEmpty {
                    Text("No reflections yet.")
                        .font(theme.body(14))
                        .foregroundStyle(theme.muted)
                } else {
                    ForEach(reflections) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(theme.muted)
                                if !r.mood.isEmpty {
                                    Text("· \(r.mood)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(theme.accent)
                                }
                            }
                            Text(r.freeformText)
                                .font(theme.body(14))
                                .foregroundStyle(theme.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if r.id != reflections.last?.id {
                            Divider().overlay(theme.hair)
                        }
                    }
                }
            }
        }
    }

    private func save() {
        let reflection = Reflection(date: .now, type: "daily")
        reflection.mood = mood
        reflection.freeformText = draft
        context.insert(reflection)
        try? context.save()
        draft = ""
        mood = ""
    }
}
