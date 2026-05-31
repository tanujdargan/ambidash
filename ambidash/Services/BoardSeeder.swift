import Foundation
import SwiftData

/// Seeds and resolves the single active `Board` for the configurable dashboard.
///
/// Build B switches `BoardView` from a hardcoded template to a DB-backed active
/// board. This service is the seam that guarantees there is always exactly one
/// active board to render: on first launch (or for any user who upgrades into the
/// board era) it materializes the default balanced `BoardTemplate` into persisted
/// `Board` + `BoardComponent` rows ONCE. Subsequent launches find the existing
/// active board and do nothing.
///
/// Pure model/SwiftData code (no SwiftUI) so it stays in the shared layer and
/// remains CloudKit-safe: it only writes additive, fully-defaulted rows.
enum BoardSeeder {

    /// The template a freshly-seeded board is built from when the user never went
    /// through the picker (e.g. an auto-seed fallback). Build C makes the
    /// ND-friendly `calm` layout the default, per the brief.
    static let defaultTemplate: BoardTemplateID = .calm

    /// Returns the active board, seeding a default one if none exists yet.
    ///
    /// Idempotent: if an active board is already present it is returned untouched.
    /// If multiple active boards somehow exist (e.g. a CloudKit merge), the
    /// lowest-`sortIndex` one wins and the rest are de-activated so the dashboard
    /// always renders a single, deterministic board.
    @discardableResult
    @MainActor
    static func ensureActiveBoard(in context: ModelContext) -> Board {
        let active = activeBoards(in: context)
        if let primary = active.first {
            // Collapse any accidental duplicates to a single active board.
            if active.count > 1 {
                for extra in active.dropFirst() { extra.isActive = false }
                try? context.save()
            }
            return primary
        }
        return seed(template: defaultTemplate, in: context)
    }

    /// Whether an active board already exists. Used by the dashboard to decide
    /// whether to show the first-run board-setup template picker (no board yet) or
    /// render the existing board directly.
    @MainActor
    static func hasActiveBoard(in context: ModelContext) -> Bool {
        !activeBoards(in: context).isEmpty
    }

    /// All active boards, deterministically ordered (sortIndex, then name).
    @MainActor
    private static func activeBoards(in context: ModelContext) -> [Board] {
        let descriptor = FetchDescriptor<Board>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Creates a new active board from a template, materializes its components with
    /// gapped per-section `sortIndex` (0,10,20…) via `BoardTemplate.apply`, and
    /// saves.
    @discardableResult
    @MainActor
    static func seed(template: BoardTemplateID, in context: ModelContext) -> Board {
        let board = Board(
            name: template.displayName,
            templateIDRaw: template.rawValue,
            isActive: true,
            sortIndex: 0
        )
        context.insert(board)
        BoardTemplate.apply(template, to: board, context: context)
        try? context.save()
        return board
    }

    /// Replaces the current board layout with a fresh instantiation of `template`
    /// (the "Customize dashboard" / re-pick path). Any existing active boards are
    /// cascade-deleted (which removes their components) and a new active board is
    /// seeded. CloudKit-safe: this only deletes/inserts whole rows, never mutates
    /// the schema.
    @discardableResult
    @MainActor
    static func replaceActiveBoard(with template: BoardTemplateID, in context: ModelContext) -> Board {
        for board in activeBoards(in: context) {
            context.delete(board)
        }
        return seed(template: template, in: context)
    }
}
