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
            .onAppear {
                apiKey = AIConfig.apiKey
            }
        }
    }
}
