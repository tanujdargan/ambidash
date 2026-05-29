// ambidash/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]
    @Query private var allPlans: [DailyPlan]
    @Query private var allReflections: [Reflection]
    @Query private var allSnapshots: [IntegrationSnapshot]

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var apiKey = ""
    @State private var subscription = SubscriptionService.shared
    @State private var showNotionSetup = false
    @State private var showObsidianPicker = false
    @State private var notionToken = ""

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            Form {
                Section("Account") {
                    if let profile {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Age", value: "\(profile.age)")
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
                        set: { tm.palette = $0 }
                    )) {
                        ForEach(ThemePalette.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    Toggle("Dark Mode", isOn: Binding(
                        get: { tm.isDark },
                        set: { tm.isDark = $0 }
                    ))

                    if tm.isDark {
                        Toggle("OLED (pure black)", isOn: Binding(
                            get: { tm.oled },
                            set: { tm.oled = $0 }
                        ))
                    }

                    Picker("Typography", selection: Binding(
                        get: { tm.typography },
                        set: { tm.typography = $0 }
                    )) {
                        ForEach(ThemeTypography.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    Picker("Density", selection: Binding(
                        get: { tm.density },
                        set: { tm.density = $0 }
                    )) {
                        ForEach(ThemeDensity.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                }
                .listRowBackground(t.surface)

                Section("Subscription") {
                    if subscription.isPremium {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(t.accent)
                            Text("Premium Active")
                                .foregroundStyle(t.ink)
                        }
                    } else {
                        Button("Upgrade to Premium") {
                            showPaywall = true
                        }
                        .foregroundStyle(t.accent)
                    }
                }
                .listRowBackground(t.surface)

                Section("AI Configuration") {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        if !apiKey.starts(with: "•") {
                            AIConfig.setApiKey(apiKey)
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    if AIConfig.isConfigured {
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
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(t.ok)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(t.accent)
                        Text("Calendar")
                            .foregroundStyle(t.ink)
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(t.ok)
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

                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundStyle(t.accent)
                        Text("Screen Time")
                            .foregroundStyle(t.ink)
                        Spacer()
                        if ScreenTimeService.shared.isAuthorized {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(t.ok)
                        } else {
                            Button("Connect") {
                                Task { await ScreenTimeService.shared.requestAuthorization() }
                            }
                            .font(.caption)
                            .foregroundStyle(t.accent)
                        }
                    }
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Notion Token", isPresented: $showNotionSetup) {
                TextField("Paste integration token", text: $notionToken)
                Button("Save") {
                    NotionService.shared.setAccessToken(notionToken)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create an integration at notion.so/my-integrations and paste the token here.")
            }
            .fileImporter(isPresented: $showObsidianPicker, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    ObsidianService.shared.setVaultURL(url)
                }
            }
            .alert("Delete Everything?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your goals, assessments, plans, reflections, and preferences. This cannot be undone.")
            }
            .onAppear {
                apiKey = AIConfig.isConfigured ? "••••••••" : ""
            }
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
