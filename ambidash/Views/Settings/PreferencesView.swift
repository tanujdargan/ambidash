// ambidash/Views/Settings/PreferencesView.swift
import SwiftUI
import SwiftData

/// FOUNDATION — the "Your Day" screen. A clean, friendly Form where the user
/// describes their real daily rhythm (wake/sleep, meals, work block, routines,
/// workout, energy). Seeded with sensible defaults that are clearly editable
/// starting points — NOT facts. Persists to SwiftData (and therefore CloudKit)
/// via a UserPreferences attached to the profile, so plan generation can build
/// the day around real anchors.
struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    // Local editable state, seeded on appear from the stored preferences (or the
    // model defaults when none exist yet). Persisted on Save.
    @State private var wakeTime = "07:00"
    @State private var sleepTime = "23:30"
    @State private var breakfastTime = "08:00"
    @State private var lunchTime = "13:00"
    @State private var dinnerTime = "19:00"
    @State private var workBusyBlock = ""
    @State private var morningRoutine = ""
    @State private var eveningRoutine = ""
    @State private var worksOut = true
    @State private var workoutTime = "18:00"
    @State private var workoutType = ""
    @State private var cooksOwnMeals = true
    @State private var energyPeak = "morning"
    @State private var focusBlocksPerDay = 3
    @State private var aboutMe = ""
    @State private var hardConstraints = ""
    @State private var extraContext = ""

    @State private var saved = false
    @State private var didSeed = false

    private let energyOptions = ["morning", "afternoon", "evening"]

    var body: some View {
        let t = tm.resolved
        Form {
            Section {
                Text("These are starting points to fine-tune, not facts. Tell us how your day usually flows so your plan fits your real life.")
                    .font(.footnote)
                    .foregroundStyle(t.muted)
            }
            .listRowBackground(t.surface)

            Section("Your day") {
                clockRow("When do you wake up?", value: $wakeTime, t: t)
                clockRow("When do you go to sleep?", value: $sleepTime, t: t)
            }
            .listRowBackground(t.surface)

            Section("Meals") {
                clockRow("Breakfast", value: $breakfastTime, t: t)
                clockRow("Lunch", value: $lunchTime, t: t)
                clockRow("Dinner", value: $dinnerTime, t: t)
                Toggle("Do you cook your own meals?", isOn: $cooksOwnMeals)
                    .tint(t.accent)
            }
            .listRowBackground(t.surface)

            Section("Work or class") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("When are you busy with work or class?")
                        .foregroundStyle(t.ink)
                    TextField("e.g. 09:00–17:00 class or work", text: $workBusyBlock, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...3)
                }
            }
            .listRowBackground(t.surface)

            Section("Routines") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your morning routine?")
                        .foregroundStyle(t.ink)
                    TextField("e.g. skincare, oral care, no phone first 30 min, coffee", text: $morningRoutine, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...4)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your evening routine?")
                        .foregroundStyle(t.ink)
                    TextField("e.g. reflection, light reading, no screens after 22:00", text: $eveningRoutine, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...4)
                }
            }
            .listRowBackground(t.surface)

            Section("Exercise") {
                Toggle("Do you work out?", isOn: $worksOut)
                    .tint(t.accent)
                if worksOut {
                    clockRow("When do you work out?", value: $workoutTime, t: t)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What kind of workout?")
                            .foregroundStyle(t.ink)
                        TextField("e.g. gym push/pull/legs, running, yoga", text: $workoutType, axis: .vertical)
                            .foregroundStyle(t.ink2)
                            .lineLimit(1...2)
                    }
                }
            }
            .listRowBackground(t.surface)

            Section("Energy & focus") {
                Picker("When's your energy highest?", selection: $energyPeak) {
                    ForEach(energyOptions, id: \.self) { opt in
                        Text(opt.capitalized).tag(opt)
                    }
                }
                Stepper("Focus blocks per day: \(focusBlocksPerDay)", value: $focusBlocksPerDay, in: 1...8)
                    .foregroundStyle(t.ink)
            }
            .listRowBackground(t.surface)

            Section("Anything else?") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A bit about you")
                        .foregroundStyle(t.ink)
                    TextField("e.g. CS student, love cooking, easily distracted", text: $aboutMe, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...4)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hard constraints")
                        .foregroundStyle(t.ink)
                    TextField("e.g. no meetings before 9am, gym closed Sundays", text: $hardConstraints, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...4)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Anything else your plan should know")
                        .foregroundStyle(t.ink)
                    TextField("Optional", text: $extraContext, axis: .vertical)
                        .foregroundStyle(t.ink2)
                        .lineLimit(1...4)
                }
            }
            .listRowBackground(t.surface)

            Section {
                Button("Save") { save() }
                if saved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(t.ok)
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(t.muted)
                    }
                }
            }
            .listRowBackground(t.surface)
        }
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle("Your Day")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: seedIfNeeded)
        .onChange(of: profiles) { _, _ in
            // Re-seed if a profile (with its preferences) syncs in after appear
            // and we haven't taken user edits yet.
            if !didSeed { seedIfNeeded() }
        }
    }

    /// A labeled HH:mm text field row with a numeric-friendly keyboard.
    @ViewBuilder
    private func clockRow(_ label: String, value: Binding<String>, t: ResolvedTheme) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(t.ink)
            Spacer()
            TextField("HH:MM", text: value)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .frame(maxWidth: 90)
                .foregroundStyle(t.ink2)
        }
    }

    /// Seeds the local fields from the stored preferences, or leaves the model
    /// defaults in place when none exist yet (so the user sees the ideal-day
    /// starting points). Runs once.
    private func seedIfNeeded() {
        guard !didSeed else { return }
        if let p = profile?.userPreferences {
            wakeTime = p.wakeTime
            sleepTime = p.sleepTime
            breakfastTime = p.breakfastTime
            lunchTime = p.lunchTime
            dinnerTime = p.dinnerTime
            workBusyBlock = p.workBusyBlock
            morningRoutine = p.morningRoutine
            eveningRoutine = p.eveningRoutine
            worksOut = p.worksOut
            workoutTime = p.workoutTime
            workoutType = p.workoutType
            cooksOwnMeals = p.cooksOwnMeals
            energyPeak = p.energyPeak
            focusBlocksPerDay = p.focusBlocksPerDay
            aboutMe = p.aboutMe
            hardConstraints = p.hardConstraints
            extraContext = p.extraContext
        } else {
            // No stored prefs yet — seed from a fresh model so defaults reflect
            // the ideal-day starting values defined on UserPreferences.
            let d = UserPreferences()
            workBusyBlock = d.workBusyBlock
            morningRoutine = d.morningRoutine
            eveningRoutine = d.eveningRoutine
            workoutType = d.workoutType
        }
        didSeed = true
    }

    /// Persists the edited fields to the profile's UserPreferences, creating both
    /// the profile and the preferences object if they don't exist yet. Syncs via
    /// CloudKit. Shows a transient "Saved" confirmation.
    private func save() {
        let target: UserProfile
        if let existing = profile {
            target = existing
        } else {
            let created = UserProfile()
            modelContext.insert(created)
            target = created
        }

        let prefs: UserPreferences
        if let existing = target.userPreferences {
            prefs = existing
        } else {
            let created = UserPreferences()
            modelContext.insert(created)
            created.profile = target
            target.userPreferences = created
            prefs = created
        }

        prefs.wakeTime = wakeTime.trimmingCharacters(in: .whitespaces)
        prefs.sleepTime = sleepTime.trimmingCharacters(in: .whitespaces)
        prefs.breakfastTime = breakfastTime.trimmingCharacters(in: .whitespaces)
        prefs.lunchTime = lunchTime.trimmingCharacters(in: .whitespaces)
        prefs.dinnerTime = dinnerTime.trimmingCharacters(in: .whitespaces)
        prefs.workBusyBlock = workBusyBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.morningRoutine = morningRoutine.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.eveningRoutine = eveningRoutine.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.worksOut = worksOut
        prefs.workoutTime = workoutTime.trimmingCharacters(in: .whitespaces)
        prefs.workoutType = workoutType.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.cooksOwnMeals = cooksOwnMeals
        prefs.energyPeak = energyPeak
        prefs.focusBlocksPerDay = focusBlocksPerDay
        prefs.aboutMe = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.hardConstraints = hardConstraints.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.extraContext = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)

        try? modelContext.save()
        Haptics.success()
        withAnimation { saved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { saved = false }
        }
    }
}
