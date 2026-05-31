import Foundation
import SwiftData

/// A Board is the configurable-component equivalent of a Notion "view": a named,
/// ordered collection of typed atomic components (`BoardComponent`) that all read
/// from the same compute-once `BoardData`. Multiple boards are different lenses
/// over the same underlying life data.
///
/// CloudKit-safe (additive-only): every scalar carries a default, the components
/// relationship is OPTIONAL, and the inverse is declared on the child side
/// (`BoardComponent.board`) only. `templateIDRaw` / kind / section / size are all
/// stored as raw strings and resolved to enums at runtime so new template/kind
/// cases never require a schema migration.
@Model
final class Board {
    var id: UUID = UUID()
    var name: String = ""
    /// Raw `BoardTemplateID` (e.g. "balanced"). Resolved at runtime; unknown
    /// values fall back gracefully. Stored as String for additive schema safety.
    var templateIDRaw: String = "balanced"
    var isActive: Bool = true
    var sortIndex: Int = 0
    /// Bumped if a future migration needs to reconcile component sets.
    var schemaVersion: Int = 1

    /// Parent side of the Board → BoardComponent relationship. Optional + cascade
    /// so deleting a board removes its components. Inverse lives on the child.
    @Relationship(deleteRule: .cascade) var components: [BoardComponent]? = nil

    init(
        id: UUID = UUID(),
        name: String = "",
        templateIDRaw: String = "balanced",
        isActive: Bool = true,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.templateIDRaw = templateIDRaw
        self.isActive = isActive
        self.sortIndex = sortIndex
        self.schemaVersion = 1
    }
}
