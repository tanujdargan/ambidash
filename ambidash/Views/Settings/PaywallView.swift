// ambidash/Views/Settings/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscription = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(AmbidashTheme.accent)

                        Text("ambidash Premium")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AmbidashTheme.accent)

                        Text("Unlock the full AI mentor experience")
                            .font(.subheadline)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "brain.head.profile", text: "Unlimited AI-powered daily plans")
                        FeatureRow(icon: "lightbulb.fill", text: "Real-time pattern insights")
                        FeatureRow(icon: "bell.badge.fill", text: "Smart guilt nudge notifications")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Monthly deep dive analytics")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Mid-day plan re-generation")
                        FeatureRow(icon: "person.fill.questionmark", text: "AI-powered honest mirror reflections")
                    }
                    .padding(.horizontal)

                    if subscription.isLoading {
                        ProgressView()
                            .tint(AmbidashTheme.accent)
                    } else if subscription.products.isEmpty {
                        VStack(spacing: 12) {
                            Text("Products not available")
                                .font(.subheadline)
                                .foregroundStyle(AmbidashTheme.textSecondary)
                            Text("Subscription products will be available once configured in App Store Connect.")
                                .font(.caption)
                                .foregroundStyle(AmbidashTheme.textTertiary)
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
                                                .foregroundStyle(AmbidashTheme.textPrimary)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundStyle(AmbidashTheme.textSecondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .foregroundStyle(AmbidashTheme.accent)
                                    }
                                    .padding()
                                    .background(AmbidashTheme.bgCard)
                                    .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                                            .stroke(AmbidashTheme.border, lineWidth: 0.5)
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
                    .foregroundStyle(AmbidashTheme.textSecondary)
                }
            }
            .background(AmbidashTheme.bgBase)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AmbidashTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AmbidashTheme.textPrimary)
        }
    }
}
