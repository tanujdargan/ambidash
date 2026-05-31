import SwiftUI

/// The "/" equivalent: a summoned add-menu for the board. One "+" trigger opens
/// this sheet, which presents every add-eligible `ComponentDescriptor` grouped by
/// `ComponentCategory`, with an auto-focused search field at the top. Tapping a row
/// inserts that kind into its `defaultSection` at `maxSort + 10` with its
/// `defaultConfig` (handled by the caller). Singletons already on the board are
/// disabled and badged "Added".
///
/// Respects `MotionPreference` (no insert animation when reduce-motion is on) and
/// fires a light haptic on a successful add.
struct AddComponentSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss

    /// Kinds currently present (visible OR hidden) on the board. Used to disable a
    /// second copy of a singleton — a hidden singleton still counts as "present"
    /// so the add-menu can't create a duplicate; the user un-hides it from edit
    /// mode instead.
    let presentKinds: Set<ComponentKind>
    /// Insert the chosen kind. The caller does the persistence + sort math and
    /// decides whether to dismiss.
    let onAdd: (ComponentKind) -> Void

    @State private var search = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: t.space.section) {
                        searchField(t)

                        if filteredGroups.isEmpty {
                            emptyState(t)
                        } else {
                            ForEach(filteredGroups, id: \.category) { group in
                                categorySection(group, t)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add component")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(t.accent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            // Auto-focus search a beat after present so the keyboard animation
            // doesn't fight the sheet transition.
            try? await Task.sleep(for: .milliseconds(350))
            searchFocused = true
        }
    }

    // MARK: - Search

    @ViewBuilder
    private func searchField(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(t.faint)
            TextField("Search components", text: $search)
                .font(.system(size: 15))
                .foregroundStyle(t.ink)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(t.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: - Category sections

    @ViewBuilder
    private func categorySection(_ group: CategoryGroup, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: group.category.title)
            VStack(spacing: 8) {
                ForEach(group.descriptors, id: \.kind) { descriptor in
                    componentRow(descriptor, t)
                }
            }
        }
    }

    @ViewBuilder
    private func componentRow(_ descriptor: ComponentDescriptor, _ t: ResolvedTheme) -> some View {
        let added = descriptor.isSingleton && presentKinds.contains(descriptor.kind)
        Button {
            guard !added else { return }
            Haptics.light()
            onAdd(descriptor.kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: descriptor.sfSymbol)
                    .font(.system(size: 16))
                    .foregroundStyle(added ? t.faint : t.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(added ? t.muted : t.ink)
                    Text(descriptor.blurb)
                        .font(.system(size: 11))
                        .foregroundStyle(t.faint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if added {
                    Text("Added")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(t.faint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(t.sunken)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(t.accent)
                }
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
        .disabled(added)
        .accessibilityLabel(added ? "\(descriptor.title), already added" : "Add \(descriptor.title). \(descriptor.blurb)")
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(t.faint)
            Text("No components match \u{201C}\(search)\u{201D}")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Filtering / grouping

    private struct CategoryGroup {
        let category: ComponentCategory
        let descriptors: [ComponentDescriptor]
    }

    /// Add-eligible descriptors filtered by the search term, then bucketed by
    /// category in a stable display order. Empty categories are dropped.
    private var filteredGroups: [CategoryGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = ComponentRegistry.allDescriptors.filter { descriptor in
            guard !query.isEmpty else { return true }
            return descriptor.title.lowercased().contains(query)
                || descriptor.blurb.lowercased().contains(query)
                || descriptor.kind.rawValue.lowercased().contains(query)
        }
        return ComponentCategory.allCases.compactMap { category in
            let inCategory = matches.filter { $0.category == category }
            return inCategory.isEmpty ? nil : CategoryGroup(category: category, descriptors: inCategory)
        }
    }
}
