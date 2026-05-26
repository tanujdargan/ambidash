// ambidash/Views/Onboarding/IntegrationSetupView.swift
import SwiftUI

struct IntegrationSetupView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var manager = IntegrationManager()
    @State private var showComplete = false
    @State private var requested = false

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect your data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(t.ink)

                        Text("ambidash works best when it can see your health and calendar data. You can change this anytime in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(t.muted)
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
                            .foregroundStyle(t.faint)
                            .padding(.horizontal)
                    }
                }
            }

            VStack(spacing: 10) {
                if !requested {
                    AccentButton(label: "Connect") {
                        Task {
                            await manager.requestAllPermissions()
                            requested = true
                        }
                    }
                }

                if requested {
                    AccentButton(label: "Continue") {
                        showComplete = true
                    }
                } else {
                    GhostButton(label: "Skip for now") {
                        showComplete = true
                    }
                }
            }
            .padding()
        }
        .background(t.bg)
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

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(connected ? t.ok : t.muted)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(t.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(t.muted)
            }

            Spacer()

            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(t.ok)
            }
        }
        .padding(14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }
}
