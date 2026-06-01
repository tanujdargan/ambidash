import SwiftUI
import SwiftData

/// The Capture Inbox dashboard component (design principle #4): the recent
/// UNPROCESSED thoughts the user dumped, with one-tap gentle triage. This is the
/// single board component that owns its own `@Query` (the inbox is inherently
/// mutated by quick-add + triage and isn't part of the static `BoardData` snapshot).
///
/// Tone rules, strictly: the header reads "Inbox", an empty inbox is a CALM rest
/// state (not "0 to do"), there is NO red "unprocessed" badge and NO backlog
/// pressure. Each row promotes to a goal / today task, archives, or drops — one tap,
/// fully reversible, never a verdict. A "+" capture affordance sits in the header so
/// the component is itself a <2s entry point.
struct CaptureInboxComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    /// Recent inbox items, newest first. Filtered to the `inbox` status only — once
    /// triaged/archived/dropped an item leaves the surface (never a guilt pile).
    @Query(
        filter: #Predicate<CaptureItem> { $0.statusRaw == "inbox" },
        sort: \CaptureItem.createdAt,
        order: .reverse
    )
    private var inbox: [CaptureItem]

    /// How many recent items the component surfaces (the rest stay quietly waiting).
    private let visibleLimit = 5

    @State private var showQuickCapture = false
    @State private var triaging: CaptureItem?

    private var visible: [CaptureItem] { Array(inbox.prefix(visibleLimit)) }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            header(t)

            if inbox.isEmpty {
                emptyState(t)
            } else {
                VStack(spacing: 8) {
                    ForEach(visible) { item in
                        CaptureInboxRow(item: item) { triaging = item }
                    }
                }
                if inbox.count > visibleLimit {
                    Text("+\(inbox.count - visibleLimit) more waiting")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.faint)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .animation(MotionPreference.animation(.ambidashSpring), value: inbox.count)
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureSheet().environment(tm)
        }
        .sheet(item: $triaging) { item in
            CaptureTriageSheet(item: item).environment(tm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Capture inbox")
    }

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title: "Inbox")
            if !inbox.isEmpty {
                Text("\(inbox.count) waiting")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            Spacer()
            Button {
                Haptics.light()
                showQuickCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.accent)
                    .frame(width: 26, height: 26)
                    .background(t.sunken.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Quick capture")
        }
    }

    /// A calm rest state — emphatically NOT "nothing to do" framed as a backlog.
    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        Button {
            Haptics.light()
            showQuickCapture = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 15))
                    .foregroundStyle(t.faint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inbox is clear.")
                        .font(t.body(13))
                        .fontWeight(.medium)
                        .foregroundStyle(t.ink)
                    Text("Tap to dump a thought — sort it later, or never.")
                        .font(t.body(11))
                        .foregroundStyle(t.muted)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inbox row

/// One waiting thought: the raw text, a relative time, a subtle source/burst hint,
/// and a single "Triage" affordance. The whole row taps to triage; no inline red,
/// no checkbox-as-failure.
private struct CaptureInboxRow: View {
    @Environment(ThemeManager.self) private var tm
    let item: CaptureItem
    let onTriage: () -> Void

    var body: some View {
        let t = tm.resolved
        Button(action: onTriage) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: kindIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(t.muted)
                    .frame(width: 16)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text)
                        .font(t.body(14))
                        .foregroundStyle(t.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(relativeTime)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(t.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.sunken.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(t.hair.opacity(0.6), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.text), captured \(relativeTime). Tap to triage.")
    }

    private var kindIcon: String {
        switch item.kindGuess {
        case .task: return "circle"
        case .goal: return "flag"
        case .note: return "text.alignleft"
        case .unknown: return "sparkle"
        }
    }

    private var relativeTime: String {
        item.createdAt.formatted(.relative(presentation: .named))
    }
}
