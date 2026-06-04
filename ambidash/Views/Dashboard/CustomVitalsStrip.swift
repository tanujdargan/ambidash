// ambidash/Views/Dashboard/CustomVitalsStrip.swift
//
// v5 feat/v5-custom-vitals — a compact dashboard surface showing the user's tracked vitals with
// today's progress, so the categories they chose are glanceable on the home screen. Renders
// nothing when no vitals are defined, so it never adds clutter by default. Tapping a chip opens
// the vitals manager.
import SwiftUI
import SwiftData

struct CustomVitalsStrip: View {
    @Environment(ThemeManager.self) private var tm
    @Query(filter: #Predicate<CustomVital> { $0.isActive }, sort: \CustomVital.sortIndex) private var vitals: [CustomVital]

    var body: some View {
        let t = tm.resolved
        if !vitals.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vitals) { vital in
                        chip(for: vital, t: t)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for vital: CustomVital, t: ResolvedTheme) -> some View {
        let summary = VitalStats.summary(
            entries: (vital.entries ?? []).map { .init(value: $0.value, date: $0.date) },
            target: vital.target
        )
        HStack(spacing: 7) {
            Image(systemName: vital.iconSymbol)
                .font(.system(size: 12)).foregroundStyle(t.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(vital.name)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(t.ink).lineLimit(1)
                Text(vital.target > 0
                     ? "\(num(summary.todayTotal))/\(num(vital.target)) \(vital.unit)"
                     : "\(num(summary.todayTotal)) \(vital.unit)")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(t.muted).lineLimit(1)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vital.name): \(num(summary.todayTotal)) \(vital.unit) today")
    }

    private func num(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
