import Foundation

/// Typed, per-kind decoders/encoders over `BoardComponent.configJSON`.
///
/// The board freezes its schema by storing config as a JSON *string*: new config
/// keys are pure additions and old clients ignore keys they don't know. These
/// helpers decode that string DEFENSIVELY — any missing key, malformed JSON, or
/// unknown enum value falls back to a sensible default instead of throwing — so a
/// component is never blank and a config synced from a newer build degrades
/// gracefully. Encoding produces a compact, stable JSON object string.
///
/// Pure Foundation (no SwiftUI / SwiftData), so it compiles into both targets and
/// can be read by `BoardData`-consuming renderers and the config sheet alike.
enum ComponentConfig {

    // MARK: - Vitals grid

    /// Config for `vitalsGrid`: which life dimensions to show (the "let people
    /// select categories for vitals" feature). An empty / missing selection means
    /// "show all dimensions" so a freshly-added grid is populated by default.
    struct Vitals: Equatable {
        /// The dimensions to render, in `LifeDimension.allCases` order. Empty =
        /// all.
        var dimensions: [LifeDimension]

        /// The default (everything) configuration.
        static let `default` = Vitals(dimensions: LifeDimension.allCases)

        /// The dimensions actually rendered: the stored selection if non-empty,
        /// otherwise every dimension. Always returned in canonical order so the
        /// grid layout is stable regardless of selection order.
        var resolvedDimensions: [LifeDimension] {
            let chosen = dimensions.isEmpty ? LifeDimension.allCases : dimensions
            let set = Set(chosen)
            return LifeDimension.allCases.filter { set.contains($0) }
        }
    }

    /// Decodes a `Vitals` config from a component's `configJSON`. Unknown/missing
    /// keys → all dimensions; unknown dimension raw values are dropped.
    static func vitals(from json: String) -> Vitals {
        guard let object = jsonObject(json),
              let raws = object["dimensions"] as? [String] else {
            return .default
        }
        let dims = raws.compactMap { LifeDimension(rawValue: $0) }
        return Vitals(dimensions: dims)
    }

    /// Encodes a `Vitals` config to a compact JSON object string.
    static func encode(_ vitals: Vitals) -> String {
        encodeObject(["dimensions": vitals.dimensions.map(\.rawValue)])
    }

    // MARK: - Today plan

    /// Config for `todayNarrow`: how many of today's planned actions to show.
    struct Today: Equatable {
        /// Number of rows to render. Clamped to a small sane range on decode.
        var rowCount: Int

        static let `default` = Today(rowCount: 3)

        /// Allowed row counts surfaced in the config sheet.
        static let allowedRowCounts = [2, 3, 4, 5]

        /// Row count clamped into the allowed range.
        var resolvedRowCount: Int { min(max(rowCount, 2), 5) }
    }

    /// Decodes a `Today` config; missing/malformed → 3 rows.
    static func today(from json: String) -> Today {
        guard let object = jsonObject(json),
              let count = object["rowCount"] as? Int else {
            return .default
        }
        return Today(rowCount: count)
    }

    static func encode(_ today: Today) -> String {
        encodeObject(["rowCount": today.rowCount])
    }

    // MARK: - JSON plumbing (defensive)

    /// Parses a JSON string into a `[String: Any]`, or nil on any failure.
    private static func jsonObject(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return nil
        }
        return dict
    }

    /// Serializes a dictionary to a compact JSON object string (sorted keys for
    /// deterministic output), falling back to "{}" on failure.
    private static func encodeObject(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ), let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
