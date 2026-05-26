// ambidash/Views/Onboarding/IntegrationSetupView.swift
import SwiftUI

struct IntegrationSetupView: View {
    @State private var manager = IntegrationManager()
    @State private var showComplete = false
    @State private var requested = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect your data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AmbidashTheme.textPrimary)

                        Text("ambidash works best when it can see your health and calendar data. You can change this anytime in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        IntegrationRow(
                            icon: "heart.fill",
                            title: "Apple Health",
                            subtitle: "Sleep, steps, workouts, heart rate",
                            connected: manager.healthAuthorized
                        )
                        IntegrationRow(
                            icon: "calendar",
                            title: "Calendar",
                            subtitle: "Events, free time for planning",
                            connected: manager.calendarAuthorized
                        )
                        IntegrationRow(
                            icon: "checklist",
                            title: "Reminders",
                            subtitle: "Overdue tasks, completion patterns",
                            connected: manager.remindersAuthorized
                        )
                    }
                    .padding(.horizontal)

                    if !requested {
                        Text("Tapping 'Connect' will show permission dialogs from iOS. We only read data — we never write or modify anything.")
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.textTertiary)
                            .padding(.horizontal)
                    }
                }
            }

            VStack(spacing: 10) {
                if !requested {
                    AccentButton("Connect", icon: "link") {
                        Task {
                            await manager.requestAllPermissions()
                            requested = true
                        }
                    }
                }

                if requested {
                    AccentButton("Continue", icon: "arrow.right") {
                        showComplete = true
                    }
                } else {
                    GhostButton(title: "Skip for now") {
                        showComplete = true
                    }
                }
            }
            .padding()
        }
        .background(AmbidashTheme.bgBase)
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
    }
}

private struct IntegrationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(connected ? AmbidashTheme.statusGood : AmbidashTheme.textSecondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AmbidashTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AmbidashTheme.textSecondary)
            }

            Spacer()

            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AmbidashTheme.statusGood)
            }
        }
        .padding(14)
        .background(AmbidashTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                .stroke(AmbidashTheme.border, lineWidth: 0.5)
        )
    }
}
