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

                        Text("ambidash works best when it can see your health and calendar data. You can change this anytime in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }
            }

            VStack(spacing: 10) {
                if !requested {
                    Button {
                        Task {
                            await manager.requestAllPermissions()
                            requested = true
                        }
                    } label: {
                        Text("Connect")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if requested {
                    Button {
                        showComplete = true
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        showComplete = true
                    } label: {
                        Text("Skip for now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
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
                .foregroundStyle(connected ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
