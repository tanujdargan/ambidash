// ambidash/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showPaywall = false
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
                    LabeledContent("Goals", value: "\(profile?.goals.count ?? 0)")
                    Button("Reset Onboarding", role: .destructive) {
                        profile?.onboardingComplete = false
                        onboardingComplete = false
                        dismiss()
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
            .onAppear {
                apiKey = AIConfig.isConfigured ? "••••••••" : ""
            }
        }
    }
}
