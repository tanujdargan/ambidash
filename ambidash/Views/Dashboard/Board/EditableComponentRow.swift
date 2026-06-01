import SwiftUI

/// Edit-mode wrapper around a single `BoardComponent`. Shows a control header (kind
/// title + drag affordance, a resize segmented control for multi-size kinds, and a
/// remove button) above a NON-interactive preview of the component itself, so the
/// user manipulates the block instead of triggering its taps. All mutations are
/// handed back to `BoardView` (which autosaves); this view holds no model state.
struct EditableComponentRow: View {
    @Environment(ThemeManager.self) private var tm

    let component: BoardComponent
    let boardData: BoardData
    let isDragging: Bool
    let onRemove: () -> Void
    let onResize: (CardSize) -> Void
    /// Open the per-kind config sheet (only offered for configurable kinds).
    let onConfigure: () -> Void

    var body: some View {
        let t = tm.resolved
        let descriptor = ComponentRegistry.descriptor(for: component.kind)

        VStack(alignment: .leading, spacing: 10) {
            header(descriptor, t)
            preview(t)
        }
        .padding(12)
        .background(t.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDragging ? t.accent : t.hair, lineWidth: isDragging ? 1.5 : 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(descriptor?.title ?? component.kindRaw) component, editing")
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ descriptor: ComponentDescriptor?, _ t: ResolvedTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundStyle(t.faint)
                .accessibilityLabel("Drag to reorder")

            Image(systemName: descriptor?.sfSymbol ?? "questionmark.square.dashed")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)

            Text(descriptor?.title ?? component.kindRaw)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            // Resize control — now LIVE: `componentSlot` applies `component.size`'s
            // width fraction in browse mode (via SizeFractionWidth), so picking S/M/L/XL
            // visibly narrows/widens the card on the board. Only shown for kinds that
            // declare more than one supported size.
            if let sizes = descriptor?.supportedSizes, sizes.count > 1 {
                resizeControl(sizes, t)
            }

            if descriptor?.isConfigurable == true {
                Button {
                    onConfigure()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15))
                        .foregroundStyle(t.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Configure \(descriptor?.title ?? "component")")
            }

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(t.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(descriptor?.title ?? "component")")
        }
    }

    /// Segmented control for the supported sizes of a multi-size kind. Tapping a
    /// size hands the change back up for persistence.
    @ViewBuilder
    private func resizeControl(_ sizes: [CardSize], _ t: ResolvedTheme) -> some View {
        HStack(spacing: 2) {
            ForEach(sizes, id: \.self) { size in
                let selected = component.size == size
                Button {
                    onResize(size)
                } label: {
                    Text(sizeLabel(size))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(selected ? t.bg : t.muted)
                        .frame(width: 24, height: 20)
                        .background(selected ? AnyShapeStyle(t.accent) : AnyShapeStyle(Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Size \(size.rawValue)\(selected ? ", selected" : "")")
            }
        }
        .padding(2)
        .background(t.sunken)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sizeLabel(_ size: CardSize) -> String {
        switch size {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        case .full: "XL"
        }
    }

    // MARK: - Preview

    /// A non-interactive rendering of the actual component so the user sees what
    /// they're arranging. `allowsHitTesting(false)` prevents taps from drilling into
    /// breakdowns / goal detail while editing; `onTapScore` is a no-op here.
    @ViewBuilder
    private func preview(_ t: ResolvedTheme) -> some View {
        ComponentRegistry.render(component, boardData: boardData, onTapScore: { _ in })
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
