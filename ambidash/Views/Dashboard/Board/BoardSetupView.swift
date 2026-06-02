import SwiftUI

/// The board-setup template picker — the "never start blank" onboarding step.
///
/// Shown two ways:
///   • `.firstRun` — on first dashboard load when no board exists yet. The user
///     can't dismiss without choosing; Calm is pre-highlighted as the default.
///   • `.customize` — from Settings → "Customize dashboard". Picking REPLACES the
///     current board layout, so it confirms before applying.
///
/// Presents 6 template cards (Calm first, default-selected) each with an icon,
/// name, blurb, and a compact preview of the component stack it lays out. The
/// caller owns persistence via `onApply(template)`.
struct BoardSetupView: View {
    enum Mode {
        /// First run: choosing seeds a brand-new board. No confirm needed.
        case firstRun
        /// Re-pick from Settings: choosing REPLACES the existing board (confirmed).
        case customize
    }

    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    /// Apply the chosen template (seed on first run, replace on customize). The
    /// caller persists and decides whether to dismiss.
    let onApply: (BoardTemplateID) -> Void

    @State private var selected: BoardTemplateID = .calm
    @State private var showReplaceConfirm = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: t.space.section) {
                        header(t)
                        VStack(spacing: 12) {
                            ForEach(BoardTemplateID.pickerOrder, id: \.self) { id in
                                templateCard(id, t)
                            }
                        }
                        applyButton(t)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(mode == .firstRun ? "Set up your dashboard" : "Customize dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if mode == .customize {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(t.muted)
                    }
                }
            }
            .alert("Replace your dashboard?", isPresented: $showReplaceConfirm) {
                Button("Replace", role: .destructive) {
                    apply()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This swaps your current layout for the \(selected.displayName) template. You can rearrange it afterward.")
            }
        }
        .presentationDragIndicator(mode == .customize ? .visible : .hidden)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .firstRun
                 ? "Pick a starting point. You can rearrange, add, or remove anything later."
                 : "Choose a new layout. This replaces your current one — you can still edit it after.")
                .font(.system(size: 14))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Template card

    @ViewBuilder
    private func templateCard(_ id: BoardTemplateID, _ t: ResolvedTheme) -> some View {
        let isSelected = selected == id
        Button {
            withAnimation(MotionPreference.animation(.ambidashSpring)) {
                selected = id
            }
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: id.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? t.bg : t.accent)
                        .frame(width: 38, height: 38)
                        .background(isSelected ? AnyShapeStyle(t.accent) : AnyShapeStyle(t.sunken))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(id.displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(t.ink)
                            if id == .calm {
                                Text("RECOMMENDED")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundStyle(t.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(t.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(id.blurb)
                            .font(.system(size: 12))
                            .foregroundStyle(t.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? t.accent : t.faint)
                }

                previewStack(id, t)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? t.accent : t.hair, lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.scalePress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(id.displayName) template\(id == .calm ? ", recommended" : "")\(isSelected ? ", selected" : ""). \(id.blurb)")
    }

    /// A tiny skeleton preview of the template's component stack — one chip per
    /// placement (icon + title), so the user gets a feel for the layout.
    @ViewBuilder
    private func previewStack(_ id: BoardTemplateID, _ t: ResolvedTheme) -> some View {
        let chips = BoardTemplate.placements(for: id).prefix(6)
        FlowChips(
            items: chips.map { placement in
                let descriptor = ComponentRegistry.descriptor(for: placement.kind)
                return PreviewChip(
                    symbol: descriptor?.sfSymbol ?? "square.dashed",
                    title: descriptor?.title ?? placement.kind.rawValue
                )
            },
            t: t
        )
    }

    // MARK: - Apply

    @ViewBuilder
    private func applyButton(_ t: ResolvedTheme) -> some View {
        Button {
            if mode == .customize {
                showReplaceConfirm = true
            } else {
                apply()
            }
        } label: {
            Text(mode == .firstRun ? "Use \(selected.displayName)" : "Apply \(selected.displayName)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(t.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(t.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.scalePress)
        .padding(.top, 4)
        .accessibilityLabel("Apply the \(selected.displayName) template")
    }

    private func apply() {
        Haptics.success()
        onApply(selected)
        dismiss()
    }
}

// MARK: - Preview chips

private struct PreviewChip: Hashable {
    let symbol: String
    let title: String
}

/// A simple wrapping row of small labeled chips. Avoids a Layout dependency by
/// using a fixed two-per-line-ish wrap via `LazyVGrid` adaptive columns.
private struct FlowChips: View {
    let items: [PreviewChip]
    let t: ResolvedTheme

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 6, alignment: .leading)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(items, id: \.self) { chip in
                HStack(spacing: 5) {
                    Image(systemName: chip.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(t.faint)
                    Text(chip.title)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(t.sunken.opacity(0.6))
                .clipShape(Capsule())
            }
        }
    }
}
