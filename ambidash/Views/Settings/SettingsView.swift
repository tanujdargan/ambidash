// ambidash/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            Form {
                Section("Account") {
                    if let profile {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Age", value: "\(profile.age)")
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("Subscription") {
                    if subscription.isPremium {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AmbidashTheme.accent)
                            Text("Premium Active")
                                .foregroundStyle(AmbidashTheme.textPrimary)
                        }
                    } else {
                        Button("Upgrade to Premium") {
                            showPaywall = true
                        }
                        .foregroundStyle(AmbidashTheme.accent)
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("AI Configuration") {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        AIConfig.setApiKey(apiKey)
                    }
                    .disabled(apiKey.isEmpty)

                    if AIConfig.isConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AmbidashTheme.statusGood)
                            Text("API key configured")
                                .font(.caption)
                                .foregroundStyle(AmbidashTheme.textSecondary)
                        }
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("Work Style") {
                    if let pref = profile?.workStylePreference {
                        LabeledContent("Plan Format", value: pref.format.displayName)
                        LabeledContent("Max Actions/Day", value: "\(pref.maxActionsPerDay)")
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("Integrations") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AmbidashTheme.statusBad)
                        Text("Apple Health")
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.statusGood)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(AmbidashTheme.accent)
                        Text("Calendar")
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.statusGood)
                    }

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(AmbidashTheme.textSecondary)
                        Text("Notion")
                            .foregroundStyle(AmbidashTheme.textPrimary)
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
                            .foregroundStyle(AmbidashTheme.accent)
                        }
                    }

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(AmbidashTheme.mindCognitive)
                        Text("Obsidian")
                            .foregroundStyle(AmbidashTheme.textPrimary)
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
                            .foregroundStyle(AmbidashTheme.accent)
                        }
                    }

                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundStyle(AmbidashTheme.statusWarn)
                        Text("Screen Time")
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Spacer()
                        if ScreenTimeService.shared.isAuthorized {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(AmbidashTheme.statusGood)
                        } else {
                            Button("Connect") {
                                Task { await ScreenTimeService.shared.requestAuthorization() }
                            }
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.accent)
                        }
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("AI Scaffolding") {
                    if let profile {
                        let level = ScaffoldingService.currentLevel(for: profile)
                        LabeledContent("Current Level", value: level.displayName)
                        Text(level.description)
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)

                Section("Data") {
                    LabeledContent("Goals", value: "\(profile?.goals.count ?? 0)")
                    Button("Reset Onboarding", role: .destructive) {
                        profile?.onboardingComplete = false
                        onboardingComplete = false
                        dismiss()
                    }
                }
                .listRowBackground(AmbidashTheme.bgCard)
            }
            .scrollContentBackground(.hidden)
            .background(AmbidashTheme.bgBase)
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
                apiKey = AIConfig.apiKey
            }
        }
    }
}
