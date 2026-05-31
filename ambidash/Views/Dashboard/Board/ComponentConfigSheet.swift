import SwiftUI

/// Progressive-disclosure config for one `BoardComponent` (the "tap card → options"
/// affordance from edit mode). Driven by per-kind config: it switches on the
/// component's kind and renders only the few options that kind exposes —
///   • `vitalsGrid` → which `LifeDimension`s appear (the "pick your vitals" feature)
///   • `todayNarrow` → how many of today's actions to show (row count)
/// Other kinds show a "nothing to configure" note so the sheet is always coherent.
///
/// Edits are committed back through `onUpdate(newConfigJSON)` (the caller persists +
/// autosaves). A live preview at the top reflects the in-progress config so the user
/// sees the effect before closing. Decode is defensive (`ComponentConfig`), so a
/// component synced from a newer build never lands here blank.
struct ComponentConfigSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss

    let component: BoardComponent
    let boardData: BoardData
    /// Commit a new `configJSON` string. The caller writes it onto the component
    /// and saves.
    let onUpdate: (String) -> Void

    // Working copies, seeded from the component's current config on appear.
    @State private var vitals: ComponentConfig.Vitals = .default
    @State private var today: ComponentConfig.Today = .default

    private var descriptor: ComponentDescriptor? {
        ComponentRegistry.descriptor(for: component.kind)
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: t.space.section) {
                        previewCard(t)
                        optionsSection(t)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(descriptor?.title ?? "Configure")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(t.accent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: seed)
    }

    // MARK: - Live preview

    @ViewBuilder
    private func previewCard(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Preview")
            preview
                .allowsHitTesting(false)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.sunken.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Renders the component with the in-progress (working) config so the preview
    /// updates live as options change.
    @ViewBuilder
    private var preview: some View {
        switch component.kind {
        case .vitalsGrid:
            VitalsGridComponent(boardData: boardData, config: vitals, onTapScore: { _ in })
        case .todayNarrow:
            TodayNarrowComponent(boardData: boardData, config: today)
        default:
            ComponentRegistry.render(component, boardData: boardData, onTapScore: { _ in })
        }
    }

    // MARK: - Per-kind options

    @ViewBuilder
    private func optionsSection(_ t: ResolvedTheme) -> some View {
        switch component.kind {
        case .vitalsGrid:
            vitalsOptions(t)
        case .todayNarrow:
            todayOptions(t)
        default:
            notConfigurable(t)
        }
    }

    // MARK: Vitals — pick which dimensions show

    @ViewBuilder
    private func vitalsOptions(_ t: ResolvedTheme) -> some View {
        let selected = Set(vitals.resolvedDimensions)
        VStack(alignment: .leading, spacing: t.space.component) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title: "Dimensions")
                Spacer()
                Text("\(selected.count) shown")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            VStack(spacing: 8) {
                ForEach(LifeDimension.allCases, id: \.self) { dim in
                    dimensionRow(dim, isOn: selected.contains(dim), t)
                }
            }
            Text("At least one dimension stays selected so the grid is never empty.")
                .font(.caption2)
                .foregroundStyle(t.faint)
        }
    }

    @ViewBuilder
    private func dimensionRow(_ dim: LifeDimension, isOn: Bool, _ t: ResolvedTheme) -> some View {
        Button {
            toggleDimension(dim)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? t.accent : t.faint)
                Text(dim.fullName)
                    .font(.system(size: 15))
                    .foregroundStyle(t.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dim.fullName)\(isOn ? ", shown" : ", hidden")")
    }

    /// Toggle a dimension in/out of the visible set. Refuses to remove the last
    /// one (the grid must show at least one gauge). Persists immediately.
    private func toggleDimension(_ dim: LifeDimension) {
        var current = vitals.resolvedDimensions
        if current.contains(dim) {
            guard current.count > 1 else { return }
            current.removeAll { $0 == dim }
        } else {
            current.append(dim)
        }
        // Re-canonicalize order and store.
        vitals = ComponentConfig.Vitals(dimensions: current).resolvedAsStored
        Haptics.selection()
        onUpdate(ComponentConfig.encode(vitals))
    }

    // MARK: Today — row count

    @ViewBuilder
    private func todayOptions(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Rows")
            HStack(spacing: 8) {
                ForEach(ComponentConfig.Today.allowedRowCounts, id: \.self) { count in
                    let isOn = today.resolvedRowCount == count
                    Button {
                        today = ComponentConfig.Today(rowCount: count)
                        Haptics.selection()
                        onUpdate(ComponentConfig.encode(today))
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isOn ? t.bg : t.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isOn ? AnyShapeStyle(t.accent) : AnyShapeStyle(t.surface))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: isOn ? 0 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(count) rows\(isOn ? ", selected" : "")")
                }
            }
            Text("How many of today's planned actions to list.")
                .font(.caption2)
                .foregroundStyle(t.faint)
        }
    }

    // MARK: Fallback

    @ViewBuilder
    private func notConfigurable(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22))
                .foregroundStyle(t.faint)
            Text("Nothing to configure here yet.")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Seeding

    private func seed() {
        vitals = ComponentConfig.vitals(from: component.configJSON)
        today = ComponentConfig.today(from: component.configJSON)
    }
}

private extension ComponentConfig.Vitals {
    /// Stores the canonical, in-order dimension list (so encode round-trips a stable
    /// order). When every dimension is selected we keep the explicit full list,
    /// which still resolves to "all".
    var resolvedAsStored: ComponentConfig.Vitals {
        ComponentConfig.Vitals(dimensions: resolvedDimensions)
    }
}
