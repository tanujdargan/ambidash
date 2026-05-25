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
                            .foregroundStyle(.blue)

                        Text("ambidash Premium")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Unlock the full AI mentor experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                    } else if subscription.products.isEmpty {
                        VStack(spacing: 12) {
                            Text("Products not available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Subscription products will be available once configured in App Store Connect.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .foregroundStyle(.secondary)
                }
            }
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
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
