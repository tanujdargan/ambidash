import Testing
import Foundation
import SwiftData
@testable import ambidash

// v5 feat/v5-customizable-board — tests for the board template system, including the two new
// named starter templates (Professional, Creative). The drag/reorder/visibility/persistence
// machinery already exists and is covered by BoardSeeder tests in V3ConfigTests; here we lock the
// template SET and the placement → persisted-component materialization.

@Test func newNamedTemplatesExist() {
    #expect(BoardTemplateID(rawValue: "professional") == .professional)
    #expect(BoardTemplateID(rawValue: "creative") == .creative)
    #expect(BoardTemplateID.professional.displayName == "Professional")
    #expect(BoardTemplateID.creative.displayName == "Creative")
}

@Test func pickerOrderContainsEveryTemplateExactlyOnce() {
    let order = BoardTemplateID.pickerOrder
    #expect(Set(order) == Set(BoardTemplateID.allCases))
    #expect(order.count == BoardTemplateID.allCases.count, "No duplicates and nothing missing")
}

@Test func everyTemplateHasNonEmptyMetadata() {
    for id in BoardTemplateID.allCases {
        #expect(!id.displayName.isEmpty)
        #expect(!id.blurb.isEmpty)
        #expect(!id.sfSymbol.isEmpty)
    }
}

@Test func everyTemplateHasPlacementsWithAHeroAndNoUnknownKinds() {
    for id in BoardTemplateID.allCases {
        let placements = BoardTemplate.placements(for: id)
        #expect(!placements.isEmpty, "\(id.rawValue) must define at least one component")
        #expect(placements.contains { $0.section == .top }, "\(id.rawValue) should have a top hero band")
        #expect(!placements.contains { $0.kind == .unknown }, "\(id.rawValue) must not place an unknown kind")
    }
}

@Test func professionalAndCreativeUseValidKnownKinds() {
    let known = Set(ComponentKind.allCases).subtracting([.unknown])
    for id in [BoardTemplateID.professional, .creative] {
        for placement in BoardTemplate.placements(for: id) {
            #expect(known.contains(placement.kind))
        }
    }
}

@MainActor
@Test func applyMaterializesGappedComponentsForNewTemplates() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    let board = Board(name: "Test", templateIDRaw: BoardTemplateID.professional.rawValue, isActive: true)
    ctx.insert(board)
    BoardTemplate.apply(.professional, to: board, context: ctx)
    try ctx.save()

    let placements = BoardTemplate.placements(for: .professional)
    let components = board.components ?? []
    #expect(components.count == placements.count)
    #expect(components.allSatisfy { $0.isVisible })

    // Per-section sortIndex is gapped by 10 starting at 0.
    let bySection = Dictionary(grouping: components, by: { $0.section })
    for (_, comps) in bySection {
        let indices = comps.map(\.sortIndex).sorted()
        let expected = (0..<indices.count).map { $0 * 10 }
        #expect(indices == expected)
    }
}

@MainActor
@Test func seederCanReplaceWithCreativeTemplate() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    _ = BoardSeeder.ensureActiveBoard(in: ctx)
    let replaced = BoardSeeder.replaceActiveBoard(with: .creative, in: ctx)
    #expect(replaced.isActive)
    #expect(replaced.templateIDRaw == "creative")
    #expect((replaced.components ?? []).isEmpty == false)
}
