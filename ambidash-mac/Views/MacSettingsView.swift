import SwiftUI
import SwiftData

/// Desktop Settings: the API key (stored in the Keychain via `AIConfig`, shared
/// with iOS), the "Your Day" daily-rhythm preferences that ground plan
/// generation, and the theme preferences exposed by `ThemeManager`. The API key
/// and "Your Day" preferences sync with iOS (Keychain / CloudKit); theme choices
/// persist to `UserDefaults` exactly as on iOS.
struct MacSettingsView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context

    @Query(sort: \UserPreferences.id) private var preferences: [UserPreferences]
    @Query private var profiles: [UserProfile]

    @State private var apiKeyDraft = ""
    @State private var savedConfirmation = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        @Bindable var theme = tm
        let r = tm.resolved
        MacScreen("Settings", subtitle: "Configure AmbiDash on this Mac") {
            EmptyView()
        } content: {
            MacCard("AI API Key") {
                Text(AIConfig.isConfigured
                     ? "A key is configured. Enter a new one to replace it."
                     : "Enter your provider API key to enable plan generation and the mentor.")
                    .font(r.body(13))
                    .foregroundStyle(r.muted)
                SecureField("sk-…", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if savedConfirmation {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(r.body(12))
                            .foregroundStyle(r.ok)
                    }
                    Spacer()
                    Button("Clear Key") {
                        AIConfig.setApiKey("")
                        apiKeyDraft = ""
                        savedConfirmation = false
                    }
                    Button("Save Key") {
                        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            AIConfig.setApiKey(trimmed)
                            apiKeyDraft = ""
                            savedConfirmation = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            yourDayCard(r)

            MacCard("Appearance") {
                Toggle("Dark mode", isOn: $theme.isDark)
                    .toggleStyle(.switch)
                Toggle("OLED (pure black)", isOn: $theme.oled)
                    .toggleStyle(.switch)
                    .disabled(!tm.isDark)

                LabeledField("Palette") {
                    Picker("Palette", selection: $theme.palette) {
                        ForEach(ThemePalette.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                LabeledField("Typography") {
                    Picker("Typography", selection: $theme.typography) {
                        ForEach(ThemeTypography.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                LabeledField("Density") {
                    Picker("Density", selection: $theme.density) {
                        ForEach(ThemeDensity.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            MacCard("Sync") {
                Text("AmbiDash for Mac shares your data with iPhone through iCloud (CloudKit). Sign into the same Apple ID on both devices and your goals, plans, reflections, and mentor letters stay in sync automatically.")
                    .font(r.body(13))
                    .foregroundStyle(r.muted)
            }
        }
    }

    // MARK: - Your Day preferences

    /// The "Your Day" form: the daily-rhythm anchors (wake/sleep, meals, work,
    /// routines, workout) that ground plan generation. Bound to the shared
    /// `UserPreferences` model so edits sync to iOS over CloudKit.
    @ViewBuilder
    private func yourDayCard(_ r: ResolvedTheme) -> some View {
        let prefs = ensurePreferences()
        @Bindable var p = prefs
        MacCard("Your Day") {
            Text("These anchors shape how plans are built — your real wake/sleep window, meals, work block, and routines.")
                .font(r.body(12))
                .foregroundStyle(r.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                LabeledField("Wake time") {
                    TextField("07:00", text: $p.wakeTime).textFieldStyle(.roundedBorder)
                }
                LabeledField("Sleep time") {
                    TextField("23:30", text: $p.sleepTime).textFieldStyle(.roundedBorder)
                }
                LabeledField("Breakfast") {
                    TextField("08:00", text: $p.breakfastTime).textFieldStyle(.roundedBorder)
                }
                LabeledField("Lunch") {
                    TextField("13:00", text: $p.lunchTime).textFieldStyle(.roundedBorder)
                }
                LabeledField("Dinner") {
                    TextField("19:00", text: $p.dinnerTime).textFieldStyle(.roundedBorder)
                }
                LabeledField("Energy peak") {
                    Picker("Energy peak", selection: $p.energyPeak) {
                        Text("Morning").tag("morning")
                        Text("Afternoon").tag("afternoon")
                        Text("Evening").tag("evening")
                    }
                    .labelsHidden()
                }
            }

            LabeledField("Work / class block") {
                TextField("09:00–17:00 class or work", text: $p.workBusyBlock)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField("Morning routine") {
                TextField("skincare, no phone first 30 min, coffee", text: $p.morningRoutine)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField("Evening routine") {
                TextField("reflection, light reading, no screens after 22:00", text: $p.eveningRoutine)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 20) {
                Toggle("Works out", isOn: $p.worksOut).toggleStyle(.switch)
                Toggle("Cooks own meals", isOn: $p.cooksOwnMeals).toggleStyle(.switch)
            }
            if p.worksOut {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LabeledField("Workout time") {
                        TextField("18:00", text: $p.workoutTime).textFieldStyle(.roundedBorder)
                    }
                    LabeledField("Workout type") {
                        TextField("gym session", text: $p.workoutType).textFieldStyle(.roundedBorder)
                    }
                }
            }

            LabeledField("Focus blocks per day") {
                Stepper(value: $p.focusBlocksPerDay, in: 1...8) {
                    Text("\(p.focusBlocksPerDay)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(r.ink)
                }
            }

            LabeledField("About me") {
                TextEditor(text: $p.aboutMe)
                    .font(r.body(13))
                    .frame(minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(r.hair, lineWidth: 1))
            }
            LabeledField("Hard constraints") {
                TextField("e.g. no work before noon on weekends", text: $p.hardConstraints)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Save Preferences") { try? context.save() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// Get-or-create the single `UserPreferences` row, always linked to the
    /// profile. Mirrors the iOS PreferencesView.save() flow: get-or-create the
    /// profile, then create+link the preferences on BOTH sides so mac-created
    /// prefs attach correctly (previously the link was skipped when no profile
    /// existed yet, leaving the prefs orphaned).
    private func ensurePreferences() -> UserPreferences {
        if let existing = preferences.first ?? profile?.userPreferences {
            return existing
        }

        // Get-or-create the profile so the new prefs always have something to link.
        let target: UserProfile
        if let existing = profile {
            target = existing
        } else {
            let created = UserProfile()
            context.insert(created)
            target = created
        }

        let prefs = UserPreferences()
        context.insert(prefs)
        prefs.profile = target
        target.userPreferences = prefs
        try? context.save()
        return prefs
    }
}
