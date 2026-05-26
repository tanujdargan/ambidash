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

                Section("Subscription") {
                    if subscription.isPremium {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                            Text("Premium Active")
                        }
                    } else {
                        Button("Upgrade to Premium") {
                            showPaywall = true
                        }
                    }
                }

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
                                .foregroundStyle(.green)
                            Text("API key configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Work Style") {
                    if let pref = profile?.workStylePreference {
                        LabeledContent("Plan Format", value: pref.format.displayName)
                        LabeledContent("Max Actions/Day", value: "\(pref.maxActionsPerDay)")
                    }
                }

                Section("Integrations") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Apple Health")
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                        Text("Calendar")
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("Notion")
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
                        }
                    }

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.purple)
                        Text("Obsidian")
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
                        }
                    }
                }

                Section("AI Scaffolding") {
                    if let profile {
                        let level = ScaffoldingService.currentLevel(for: profile)
                        LabeledContent("Current Level", value: level.displayName)
                        Text(level.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    LabeledContent("Goals", value: "\(profile?.goals.count ?? 0)")
                    Button("Reset Onboarding", role: .destructive) {
                        profile?.onboardingComplete = false
                        onboardingComplete = false
                        dismiss()
                    }
                }
            }
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
