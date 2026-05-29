// ambidash/Views/Settings/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var tm
    @State private var subscription = SubscriptionService.shared

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(t.accent)

                        Text("ambidash Premium")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(t.accent)

                        Text("Unlock the full AI mentor experience")
                            .font(.subheadline)
                            .foregroundStyle(t.muted)
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "brain.head.profile", text: "Unlimited AI-powered daily plans")
                        FeatureRow(icon: "lightbulb.fill", text: "Real-time pattern insights")
                        FeatureRow(icon: "bell.badge.fill", text: "Gentle, progress-forward nudges & review reminders")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Monthly deep dive analytics")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Mid-day plan re-generation")
                        FeatureRow(icon: "person.fill.questionmark", text: "AI-powered honest mirror reflections")
                    }
                    .padding(.horizontal)

                    if subscription.isLoading {
                        ProgressView()
                            .tint(t.accent)
                    } else if subscription.products.isEmpty {
                        VStack(spacing: 12) {
                            Text("Products not available")
                                .font(.subheadline)
                                .foregroundStyle(t.muted)
                            Text("Subscription products will be available once configured in App Store Connect.")
                                .font(.caption)
                                .foregroundStyle(t.faint)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(subscription.products.sorted(by: { $0.price < $1.price })) { product in
                                Button {
                                    Task {
                                        let success = await subscription.purchase(product)
                                        if success { dismiss() }
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .font(.headline)
                                                .foregroundStyle(t.ink)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundStyle(t.muted)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .foregroundStyle(t.accent)
                                    }
                                    .padding()
                                    .background(t.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(t.hair, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button("Restore Purchases") {
                        Task { await subscription.restorePurchases() }
                    }
                    .font(.caption)
                    .foregroundStyle(t.muted)
                }
            }
            .background(t.bg)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscription.loadProducts()
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(t.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(t.ink)
        }
    }
}
