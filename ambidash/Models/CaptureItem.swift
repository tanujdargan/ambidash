import Foundation
import SwiftData

/// A single UNCATEGORIZED thought dropped into the universal capture inbox — the
/// "WhatsApp self-chat" replacement (design principle #4, the single most-validated
/// need). The whole point is a <2-second dump: the user types a thought and it lands
/// here with NO category, NO goal, NO due date required. Triage happens LATER (and
/// gently): an item can be promoted into a Goal or a today task, archived, or
/// dropped — but it is NEVER pressured and an un-triaged inbox NEVER shows a red
/// "unprocessed" badge.
///
/// CloudKit-safe (additive-only): every scalar is defaulted, the optional `links`
/// are plain `UUID?` (no relationships, so this model adds zero relationship
/// surface to migrate), and the status/kind/source enums are STRING-keyed with an
/// `.unknown`-style fallback so an older client that doesn't know a value resolves
/// it safely. Registered in BOTH ModelContainers (AmbidashApp.swift +
/// AmbidashMacApp.swift).
@Model
final class CaptureItem: Identifiable {
    var id: UUID = UUID()
    /// The raw thought, exactly as typed. No parsing on the way in.
    var text: String = ""
    var createdAt: Date = Date()

    /// Lifecycle as a raw string (resolved to `CaptureStatus`, unknown → `.inbox`).
    /// inbox = waiting (the default, never shamed) · triaged = acted on (promoted) ·
    /// archived = kept but set aside · dropped = discarded (kept as a tombstone so
    /// it doesn't resurface, but recoverable).
    var statusRaw: String = "inbox"

    /// Where the capture came from (resolved to `CaptureSource`, unknown → `.text`).
    /// text is the MVP; voice/share are phase-2 entry points that reuse this model.
    var sourceRaw: String = "text"

    /// A LOCAL, non-authoritative guess at what this thought is (resolved to
    /// `CaptureKindGuess`, unknown → `.unknown`). Used only to pre-suggest a triage
    /// affordance; never blocks capture, never shown as a verdict.
    var kindGuessRaw: String = ""

    /// Burst-grouping: consecutive captures within a short window share a `groupID`
    /// so the inbox can present "you dumped these together" as one cluster. nil for
    /// an ungrouped single capture.
    var groupID: UUID?

    /// When this item was triaged (promoted/archived/dropped). nil while in inbox.
    /// Drives "recent unprocessed" filtering without a separate flag.
    var triagedAt: Date?

    /// If promoted, the id of the thing it became (a Goal.id or a PlannedAction.id).
    /// Plain UUID? (NOT a relationship) to keep the CloudKit surface additive and
    /// avoid a cross-model relationship migration.
    var promotedToID: UUID?

    init(
        id: UUID = UUID(),
        text: String = "",
        createdAt: Date = .now,
        statusRaw: String = "inbox",
        sourceRaw: String = "text",
        kindGuessRaw: String = "",
        groupID: UUID? = nil,
        triagedAt: Date? = nil,
        promotedToID: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.statusRaw = statusRaw
        self.sourceRaw = sourceRaw
        self.kindGuessRaw = kindGuessRaw
        self.groupID = groupID
        self.triagedAt = triagedAt
        self.promotedToID = promotedToID
    }

    // MARK: - Runtime resolution (raw string → enum, safe fallbacks)

    var status: CaptureStatus {
        get { CaptureStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .text }
        set { sourceRaw = newValue.rawValue }
    }

    var kindGuess: CaptureKindGuess {
        get { CaptureKindGuess(rawValue: kindGuessRaw) ?? .unknown }
        set { kindGuessRaw = newValue.rawValue }
    }

    /// True while the item is still waiting in the inbox (the only thing the inbox
    /// component surfaces). Never a "failure" state.
    var isInbox: Bool { status == .inbox }
}

// MARK: - String-keyed enums (additive / forward-compatible)

/// Lifecycle of a capture. STRING-keyed so new states are additive and an older
/// client resolves an unknown value to `.inbox` (it just keeps waiting — never
/// breaks, never shames).
enum CaptureStatus: String, CaseIterable, Codable, Hashable {
    case inbox
    case triaged
    case archived
    case dropped
}

/// Entry point a capture came from. `text` is the MVP; `voice` and `share` are
/// phase-2 surfaces that reuse the same model. STRING-keyed, unknown → `.text`.
enum CaptureSource: String, CaseIterable, Codable, Hashable {
    case text
    case voice
    case share
    case widget
}

/// A gentle, LOCAL guess at what a captured thought is, used only to pre-select a
/// suggested triage action. Never authoritative, never shown as a verdict. The
/// on-device / BYOK decompose may refine this; a plain heuristic seeds it so the
/// flow works with no model at all. STRING-keyed, unknown → `.unknown`.
enum CaptureKindGuess: String, CaseIterable, Codable, Hashable {
    /// Looks like a small, doable action → suggest "add to today".
    case task
    /// Looks like a longer-range aspiration → suggest "make a goal".
    case goal
    /// Looks like a note/idea with no obvious action → suggest "keep" (archive).
    case note
    case unknown

    /// The capture component's suggested primary triage for this guess.
    var suggestedTriage: CaptureTriageAction {
        switch self {
        case .task: return .makeTask
        case .goal: return .makeGoal
        case .note: return .archive
        case .unknown: return .makeTask
        }
    }
}

/// The four gentle triage outcomes for an inbox item. Not persisted directly — it
/// drives the one-tap triage UI and maps to a `CaptureStatus` transition.
enum CaptureTriageAction: String, CaseIterable, Hashable {
    case makeGoal
    case makeTask
    case archive
    case drop
}
