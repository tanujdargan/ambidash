// ambidash/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]
    @Query private var allPlans: [DailyPlan]
    @Query private var allReflections: [Reflection]
    @Query private var allSnapshots: [IntegrationSnapshot]

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    /// v4 calendar integration: auto-mirror newly-added goals into Reminders.
    @AppStorage("calendar_sync_enabled") private var calendarSyncEnabled = false
    @State private var showDeleteConfirmation = false
    @State private var apiKey = ""
    @State private var showNotionSetup = false
    @State private var showObsidianPicker = false
    @State private var notionToken = ""
    @State private var showGoalImporter = false
    @State private var importMessage: String?
    /// Presents the board-setup template picker in "customize" (replace) mode.
    @State private var showBoardSetup = false
    /// Transient "Saved ✓" confirmation under the Save API Key button.
    @State private var apiKeySaved = false

    // Editable profile fields. Seeded from the profile on appear; persisted (and
    // a UserProfile created if none exists) when the user taps Save.
    @State private var nameField = ""
    @State private var ageField = ""
    @State private var profileSaved = false
    /// Tracks whether the user has edited Name/Age since seeding, so a profile
    /// syncing in later doesn't clobber in-progress edits.
    @State private var profileFieldsSeeded = false
    /// Focus for the numberPad Age field, so the keyboard toolbar Done can resign
    /// it (numberPad has no return key).
    @FocusState private var ageFocused: Bool
    /// Real integration permission state for the Integrations rows (loaded in `.task`),
    /// so Apple Health / Calendar reflect actual authorization instead of a hardcoded
    /// "Connected".
    @State private var healthAuthorized = false
    @State private var calendarAuthorized = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Account") {
                    // Editable Name/Age. Works even when no UserProfile exists
                    // (e.g. the "I've been here before" onboarding skip): saving
                    // creates one. Fields are seeded in .onAppear.
                    HStack {
                        Text("Name")
                            .foregroundStyle(t.ink)
                        Spacer()
                        TextField("Your name", text: $nameField)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.name)
                            .foregroundStyle(t.ink)
                    }

                    HStack {
                        Text("Age")
                            .foregroundStyle(t.ink)
                        Spacer()
                        TextField("Age", text: $ageField)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($ageFocused)
                            .frame(maxWidth: 80)
                            .foregroundStyle(t.ink)
                    }

                    Button("Save Profile") { saveProfile() }
                        .disabled(!profileFieldsChanged)

                    if profileSaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(t.ok)
                            Text("Saved")
                                .font(.caption)
                                .foregroundStyle(t.muted)
                        }
                    }

                    if SupabaseService.shared.isAuthenticated {
                        LabeledContent("Signed in", value: SupabaseService.shared.userId?.prefix(8).description ?? "")
                        Button("Sign Out", role: .destructive) {
                            SupabaseService.shared.signOut()
                            dismiss()
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section("Appearance") {
                    Picker("Palette", selection: Binding(
                        get: { tm.palette },
                        set: { tm.palette = $0; Haptics.selection() }
                    )) {
                        ForEach(ThemePalette.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    Toggle("Dark Mode", isOn: Binding(
                        get: { tm.isDark },
                        set: { tm.isDark = $0; Haptics.selection() }
                    ))

                    if tm.isDark {
                        Toggle("OLED (pure black)", isOn: Binding(
                            get: { tm.oled },
                            set: { tm.oled = $0; Haptics.selection() }
                        ))
                    }

                    Picker("Typography", selection: Binding(
                        get: { tm.typography },
                        set: { tm.typography = $0; Haptics.selection() }
                    )) {
                        ForEach(ThemeTypography.allCases) { t in
                            Text(t.displayName)
                                // "typography.editorial/.modern/.technical" — segmented
                                // so each option is a directly-tappable button the UI
                                // tests can find by identifier.
                                .accessibilityIdentifier("typography.\(t.rawValue)")
                                .tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Density", selection: Binding(
                        get: { tm.density },
                        set: { tm.density = $0; Haptics.selection() }
                    )) {
                        ForEach(ThemeDensity.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }

                    Text("Typography changes the heading & body font family. Density adjusts spacing on the main screens.")
                        .font(.caption2)
                        .foregroundStyle(t.faint)
                }
                .listRowBackground(t.surface)

                Section("Dashboard") {
                    Button {
                        showBoardSetup = true
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundStyle(t.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Customize dashboard")
                                    .foregroundStyle(t.ink)
                                Text("Pick a new layout template — Calm, Balanced, and more")
                                    .font(.caption)
                                    .foregroundStyle(t.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(t.faint)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(t.surface)

                Section("AI Configuration") {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") { saveApiKey() }
                    .disabled(apiKey.isEmpty || apiKey.starts(with: "•"))

                    if apiKeySaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(t.ok)
                            Text("Saved")
                                .font(.caption)
                                .foregroundStyle(t.muted)
                        }
                    } else if AIConfig.isConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(t.ok)
                            Text("API key configured")
                                .font(.caption)
                                .foregroundStyle(t.muted)
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section("Preferences") {
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        HStack {
                            Image(systemName: "sun.max")
                                .foregroundStyle(t.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Day")
                                    .foregroundStyle(t.ink)
                                Text("Wake, meals, routines & focus — so plans fit your real life")
                                    .font(.caption)
                                    .foregroundStyle(t.muted)
                            }
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section("Work Style") {
                    if let pref = profile?.workStylePreference {
                        LabeledContent("Plan Format", value: pref.format.displayName)
                        LabeledContent("Max Actions/Day", value: "\(pref.maxActionsPerDay)")
                    }
                }
                .listRowBackground(t.surface)

                Section("Integrations") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(t.danger)
                        Text("Apple Health")
                            .foregroundStyle(t.ink)
                        Spacer()
                        if healthAuthorized {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(t.ok)
                        } else {
                            Button("Connect") {
                                Task {
                                    _ = await HealthKitService.shared.requestAuthorization()
                                    healthAuthorized = await HealthKitService.shared.isAuthorized()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(t.accent)
                        }
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(t.accent)
                        Text("Calendar")
                            .foregroundStyle(t.ink)
                        Spacer()
                        if calendarAuthorized {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(t.ok)
                        } else {
                            Button("Connect") {
                                Task {
                                    _ = await EventKitService.shared.requestCalendarAccess()
                                    calendarAuthorized = EventKitService.shared.isCalendarAuthorized
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(t.accent)
                        }
                    }

                    Toggle(isOn: $calendarSyncEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add goals to Calendar")
                                .foregroundStyle(t.ink)
                            Text("New goals drop a reminder so they show up automatically")
                                .font(.caption)
                                .foregroundStyle(t.muted)
                        }
                    }
                    .tint(t.accent)
                    .accessibilityIdentifier("settings.calendarSync")
                    .onChange(of: calendarSyncEnabled) { _, on in
                        if on { Task { _ = await EventKitService.shared.requestRemindersAccess() } }
                        Haptics.selection()
                    }

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(t.muted)
                        Text("Notion")
                            .foregroundStyle(t.ink)
                        Spacer()
                        if NotionService.shared.isConnected {
                            Button("Disconnect", role: .destructive) {
                                NotionService.shared.disconnect()
                            }
                            .font(.caption)
                        } else {
                            Button("Connect") {
                                showNotionSetup = true
                            }
                            .font(.caption)
                            .foregroundStyle(t.accent)
                        }
                    }

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(AmbidashTheme.dimensionColor(for: .mind))
                        Text("Obsidian")
                            .foregroundStyle(t.ink)
                        Spacer()
                        if ObsidianService.shared.isConnected {
                            Button("Disconnect", role: .destructive) {
                                ObsidianService.shared.disconnect()
                            }
                            .font(.caption)
                        } else {
                            Button("Connect") {
                                showObsidianPicker = true
                            }
                            .font(.caption)
                            .foregroundStyle(t.accent)
                        }
                    }

                    NavigationLink {
                        AppLimitsView()
                    } label: {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundStyle(t.accent)
                            Text("App Limits")
                                .foregroundStyle(t.ink)
                            Spacer()
                            Text("Block apps")
                                .font(.caption)
                                .foregroundStyle(t.muted)
                        }
                    }
                    .accessibilityIdentifier("settings.appLimits")
                }
                .listRowBackground(t.surface)

                Section("AI Scaffolding") {
                    if let profile {
                        let level = ScaffoldingService.currentLevel(for: profile)
                        LabeledContent("Current Level", value: level.displayName)
                        Text(level.description)
                            .font(.caption)
                            .foregroundStyle(t.muted)
                    }
                }
                .listRowBackground(t.surface)

                Section("Data") {
                    LabeledContent("Goals", value: "\(profile?.goals?.count ?? 0)")

                    if let profile {
                        ShareLink(
                            item: exportData(profile: profile),
                            preview: SharePreview("AmbiDash Export", image: Image(systemName: "square.and.arrow.up"))
                        ) {
                            Label("Export My Data", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        showGoalImporter = true
                    } label: {
                        Label("Import Goals from File", systemImage: "square.and.arrow.down")
                    }

                    Button("Reset Onboarding", role: .destructive) {
                        profile?.onboardingComplete = false
                        onboardingComplete = false
                        dismiss()
                    }
                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
                .listRowBackground(t.surface)
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .task {
                healthAuthorized = await HealthKitService.shared.isAuthorized()
                calendarAuthorized = EventKitService.shared.isCalendarAuthorized
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                // The Age field uses a numberPad, which has no return key — give
                // it a keyboard toolbar Done so it can be dismissed.
                if ageFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { ageFocused = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Notion Token", isPresented: $showNotionSetup) {
                TextField("Paste integration token", text: $notionToken)
                Button("Save") {
                    // Guard empty/whitespace so a blank Save doesn't store ""
                    // (non-nil) and falsely flip the row to "Connected".
                    let t = notionToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    notionToken = ""
                    guard !t.isEmpty else { return }
                    NotionService.shared.setAccessToken(t)
                }
                Button("Cancel", role: .cancel) { notionToken = "" }
            } message: {
                Text("Create an integration at notion.so/my-integrations and paste the token here.")
            }
            .fileImporter(isPresented: $showObsidianPicker, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    ObsidianService.shared.setVaultURL(url)
                }
            }
            .fileImporter(isPresented: $showGoalImporter, allowedContentTypes: [.json]) { result in
                handleGoalImport(result)
            }
            .alert("Import Goals", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .alert("Delete Everything?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your goals, assessments, plans, reflections, and preferences. This cannot be undone.")
            }
            .sheet(isPresented: $showBoardSetup) {
                BoardSetupView(mode: .customize) { template in
                    BoardSeeder.replaceActiveBoard(with: template, in: modelContext)
                }
                .environment(tm)
            }
            .onAppear {
                apiKey = AIConfig.isConfigured ? "••••••••" : ""
                seedProfileFields()
            }
            .onChange(of: profiles) { _, _ in
                // A profile can sync in via CloudKit after this view appears. Seed
                // the Name/Age fields from it then so the user edits the existing
                // profile rather than a blank form that would create a duplicate.
                // Don't clobber edits already in progress.
                if !profileFieldsSeeded { seedProfileFields() }
            }
        }
    }

    /// True when the editable Name/Age differ from the stored profile (or there
    /// is no profile yet but the user has typed something), enabling Save.
    private var profileFieldsChanged: Bool {
        let trimmedName = nameField.trimmingCharacters(in: .whitespaces)
        let typedAge = Int(ageField.trimmingCharacters(in: .whitespaces))
        guard let profile else {
            return !trimmedName.isEmpty || typedAge != nil
        }
        let storedAge = profile.age > 0 ? profile.age : nil
        return trimmedName != profile.name || typedAge != storedAge
    }

    /// Seeds the editable Name/Age fields from the stored profile (when one
    /// exists) and marks them seeded so a later CloudKit sync doesn't re-seed over
    /// the user's edits.
    private func seedProfileFields() {
        guard let profile = profiles.first else { return }
        nameField = profile.name
        ageField = profile.age > 0 ? "\(profile.age)" : ""
        profileFieldsSeeded = true
    }

    /// Persists Name/Age, creating a UserProfile on first edit when none exists
    /// so users who skipped onboarding can still set their identity (synced via
    /// CloudKit). Shows a transient "Saved" confirmation.
    private func saveProfile() {
        let trimmedName = nameField.trimmingCharacters(in: .whitespaces)
        let parsedAge = Int(ageField.trimmingCharacters(in: .whitespaces)) ?? 0

        let target: UserProfile
        // Re-read profiles.first here (not the value captured at view build) so a
        // profile that synced in after appear is reused — never insert a second
        // UserProfile if one now exists.
        if let existing = profiles.first {
            target = existing
        } else {
            let created = UserProfile(name: trimmedName, age: parsedAge)
            modelContext.insert(created)
            target = created
        }
        target.name = trimmedName
        target.age = parsedAge
        try? modelContext.save()
        profileFieldsSeeded = true

        Haptics.success()
        withAnimation { profileSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { profileSaved = false }
        }
    }

    /// Persists the entered API key to the keychain (ignoring the masked
    /// placeholder), then masks the field and shows a transient confirmation.
    private func saveApiKey() {
        // Trim before saving (matches MacSettingsView): a pasted key with a
        // leading/trailing space or newline otherwise stores verbatim and 401s.
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.starts(with: "•"), !key.isEmpty else { return }
        AIConfig.setApiKey(key)
        apiKey = "••••••••"
        Haptics.success()
        withAnimation { apiKeySaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { apiKeySaved = false }
        }
    }

    private func handleGoalImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't read that file."
                return
            }
            let summary = GoalImportService.importGoals(from: data, context: modelContext, profile: profile)
            if let err = summary.error {
                importMessage = err
            } else {
                let skip = summary.skipped > 0 ? " · skipped \(summary.skipped) already there/empty" : ""
                importMessage = "Imported \(summary.imported) goal\(summary.imported == 1 ? "" : "s")\(skip)."
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func exportData(profile: UserProfile) -> URL {
        let data = DataExportService.exportJSON(
            profile: profile,
            plans: allPlans,
            reflections: allReflections,
            snapshots: allSnapshots
        ) ?? Data()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ambidash-export.json")
        try? data.write(to: url)
        return url
    }

    private func deleteAllData() {
        // Delete all SwiftData models
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: Goal.self)
        try? modelContext.delete(model: CoreAssessment.self)
        try? modelContext.delete(model: WorkStylePreference.self)
        try? modelContext.delete(model: UserPreferences.self)
        try? modelContext.delete(model: DomainAssessment.self)
        try? modelContext.delete(model: GoalProgress.self)
        try? modelContext.delete(model: Streak.self)
        try? modelContext.delete(model: IntegrationSnapshot.self)
        try? modelContext.delete(model: DailyPlan.self)
        try? modelContext.delete(model: PlannedAction.self)
        try? modelContext.delete(model: Reflection.self)
        try? modelContext.delete(model: MentorFeedback.self)
        try? modelContext.save()

        // Clear preferences
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "theme_palette")
        defaults.removeObject(forKey: "theme_dark")
        defaults.removeObject(forKey: "theme_typography")
        defaults.removeObject(forKey: "theme_density")
        defaults.removeObject(forKey: "theme_setup_complete")
        defaults.removeObject(forKey: "onboardingComplete")
        defaults.removeObject(forKey: "screentime_authorized")
        defaults.removeObject(forKey: "notion_access_token")
        defaults.removeObject(forKey: "obsidian_vault_bookmark")
        defaults.removeObject(forKey: "daily_insight_count")
        defaults.removeObject(forKey: "daily_plan_count")
        defaults.removeObject(forKey: "daily_count_reset_date")

        // Clear API key from Keychain
        AIConfig.setApiKey("")

        // Reset navigation state
        onboardingComplete = false
        dismiss()
    }
}
