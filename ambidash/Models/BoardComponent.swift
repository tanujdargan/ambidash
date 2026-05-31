import Foundation
import SwiftData

/// A BoardComponent is a single typed "block" on a Board — the Notion-block
/// analogue. Its identity is `kindRaw` (resolved to `ComponentKind`); placement is
/// `sectionRaw` (resolved to `BoardSection`) + `sortIndex` (gapped 0,10,20 so
/// re-ordering is cheap); rendered size is `sizeRaw` (resolved to `CardSize`); and
/// per-kind options live in `configJSON` (a JSON string decoded lazily at render).
///
/// CloudKit-safe (additive-only): all scalars defaulted, the `board` relationship
/// is optional, and the inverse is declared HERE (the child side) only. Storing
/// kind/section/size as raw strings + freezing config behind a JSON string means
/// new kinds and config shapes are pure additions — zero migration. Unknown
/// `kindRaw` resolves to `.unknown` → `UnavailableComponentCard`.
@Model
final class BoardComponent: Identifiable {
    var id: UUID = UUID()
    /// Raw `ComponentKind` (e.g. "compositeScore"). Unknown → `.unknown`.
    var kindRaw: String = ""
    /// Raw `BoardSection` (top / body / focus). Unknown → `.body`.
    var sectionRaw: String = "body"
    /// Ordering within a section. Gapped by 10 so inserts/reorders rarely renumber.
    var sortIndex: Int = 0
    /// Soft-removal flag: hidden components stay persisted (reversible) and are
    /// filtered out of the render tree.
    var isVisible: Bool = true
    /// Raw `CardSize` (small / medium / large / full). Unknown → `.medium`.
    var sizeRaw: String = "medium"
    /// Per-kind options as a JSON object string. Decoded lazily + memoized at
    /// render time. Frozen schema while configs evolve.
    var configJSON: String = "{}"

    /// Child side of the relationship; carries the inverse to `Board.components`.
    /// Optional + additive per the CloudKit rule.
    @Relationship(inverse: \Board.components) var board: Board?

    init(
        id: UUID = UUID(),
        kindRaw: String = "",
        sectionRaw: String = "body",
        sortIndex: Int = 0,
        isVisible: Bool = true,
        sizeRaw: String = "medium",
        configJSON: String = "{}"
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.sectionRaw = sectionRaw
        self.sortIndex = sortIndex
        self.isVisible = isVisible
        self.sizeRaw = sizeRaw
        self.configJSON = configJSON
    }

    // MARK: - Runtime resolution (raw string → enum, with safe fallbacks)

    /// Resolved component kind; unknown raw values become `.unknown`.
    var kind: ComponentKind { ComponentKind(rawValue: kindRaw) ?? .unknown }
    /// Resolved section; unknown raw values become `.body`.
    var section: BoardSection { BoardSection(rawValue: sectionRaw) ?? .body }
    /// Resolved size; unknown raw values become `.medium`.
    var size: CardSize { CardSize(rawValue: sizeRaw) ?? .medium }
}
