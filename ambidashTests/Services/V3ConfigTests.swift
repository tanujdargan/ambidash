// ambidashTests/Services/V3ConfigTests.swift
//
// V3 happy-path tests for ComponentConfig JSON round-trips (and defensive
// tolerance of missing/malformed keys) plus BoardSeeder seeding a populated board.
import Testing
import Foundation
import SwiftData
@testable import ambidash

// MARK: - ComponentConfig: Vitals

@Test func vitalsConfigRoundTrips() {
    let original = ComponentConfig.Vitals(dimensions: [.body, .mind])
    let json = ComponentConfig.encode(original)
    let decoded = ComponentConfig.vitals(from: json)
    #expect(decoded.dimensions == [.body, .mind])
}

@Test func vitalsConfigMissingKeyFallsBackToAll() {
    let decoded = ComponentConfig.vitals(from: "{}")
    #expect(decoded == .default)
    #expect(decoded.dimensions == LifeDimension.allCases)
}

@Test func vitalsConfigMalformedJSONFallsBackToAll() {
    let decoded = ComponentConfig.vitals(from: "not json at all")
    #expect(decoded == .default)
}

@Test func vitalsConfigDropsUnknownDimensionRawValues() {
    let decoded = ComponentConfig.vitals(from: #"{"dimensions":["body","not_a_dimension","mind"]}"#)
    #expect(decoded.dimensions == [.body, .mind])
}

@Test func vitalsResolvedDimensionsAreInCanonicalOrder() {
    // Stored out of order → resolved in LifeDimension.allCases order.
    let v = ComponentConfig.Vitals(dimensions: LifeDimension.allCases.reversed())
    #expect(v.resolvedDimensions == LifeDimension.allCases)
    // Empty selection resolves to all.
    let empty = ComponentConfig.Vitals(dimensions: [])
    #expect(empty.resolvedDimensions == LifeDimension.allCases)
}

// MARK: - ComponentConfig: Today

@Test func todayConfigRoundTrips() {
    let original = ComponentConfig.Today(rowCount: 4)
    let json = ComponentConfig.encode(original)
    let decoded = ComponentConfig.today(from: json)
    #expect(decoded.rowCount == 4)
}

@Test func todayConfigMissingKeyFallsBackToDefault() {
    #expect(ComponentConfig.today(from: "{}").rowCount == 3)
    #expect(ComponentConfig.today(from: "garbage").rowCount == 3)
}

@Test func todayResolvedRowCountClampsToRange() {
    #expect(ComponentConfig.Today(rowCount: 99).resolvedRowCount == 5)
    #expect(ComponentConfig.Today(rowCount: 0).resolvedRowCount == 2)
    #expect(ComponentConfig.Today(rowCount: 3).resolvedRowCount == 3)
}

// MARK: - BoardSeeder

@MainActor
@Test func boardSeederSeedsPopulatedActiveBoard() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    #expect(BoardSeeder.hasActiveBoard(in: ctx) == false)

    let board = BoardSeeder.ensureActiveBoard(in: ctx)
    #expect(board.isActive == true)
    #expect((board.components ?? []).isEmpty == false, "A seeded board must have components")
    #expect(BoardSeeder.hasActiveBoard(in: ctx) == true)
}

@MainActor
@Test func boardSeederIsIdempotent() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    let first = BoardSeeder.ensureActiveBoard(in: ctx)
    let second = BoardSeeder.ensureActiveBoard(in: ctx)
    #expect(first.id == second.id, "Re-ensuring returns the same active board, not a new one")

    let descriptor = FetchDescriptor<Board>(predicate: #Predicate { $0.isActive })
    let activeBoards = try ctx.fetch(descriptor)
    #expect(activeBoards.count == 1, "Only one active board exists after repeated ensures")
}

@MainActor
@Test func boardSeederReplaceSwapsActiveBoard() throws {
    let container = try V3TestSupport.makeContainer()
    let ctx = ModelContext(container)

    _ = BoardSeeder.ensureActiveBoard(in: ctx)
    let replaced = BoardSeeder.replaceActiveBoard(with: .calm, in: ctx)
    #expect(replaced.isActive == true)

    let descriptor = FetchDescriptor<Board>(predicate: #Predicate { $0.isActive })
    let activeBoards = try ctx.fetch(descriptor)
    #expect(activeBoards.count == 1, "Replacing leaves exactly one active board")
}
