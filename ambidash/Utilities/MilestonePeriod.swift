import SwiftUI

/// The cadence band a Milestone node occupies inside a goal's decomposition
/// chain (year → quarter → month → week). Mirrors `GoalHorizon`'s structure so
/// the same "one enum field decides the variant" convention drives the
/// self-referential Milestone tree. The order of `allCases` is coarse→fine,
/// matching the natural top-to-bottom nesting of the chain.
enum MilestonePeriod: String, CaseIterable, Codable, Identifiable {
    case year, quarter, month, week

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .year: "Year"
        case .quarter: "Quarter"
        case .month: "Month"
        case .week: "Week"
        }
    }

    var timeframe: String {
        switch self {
        case .year: "12 months"
        case .quarter: "3 months"
        case .month: "1 month"
        case .week: "1 week"
        }
    }

    var dotColor: Color {
        switch self {
        case .year: Color(hex: 0x7F77DD)
        case .quarter: Color(hex: 0x378ADD)
        case .month: Color(hex: 0xEF9F27)
        case .week: Color(hex: 0x1D9E75)
        }
    }

    /// Approximate span of one node of this period, in days. Used by
    /// `MilestoneGenerator` date math when laying out a default chain.
    var approximateDays: Int {
        switch self {
        case .year: 365
        case .quarter: 91
        case .month: 30
        case .week: 7
        }
    }

    /// The Calendar component a node of this period advances by when computing
    /// the next period window (e.g. quarter → 3 months).
    var calendarStep: (component: Calendar.Component, value: Int) {
        switch self {
        case .year: (.year, 1)
        case .quarter: (.month, 3)
        case .month: (.month, 1)
        case .week: (.weekOfYear, 1)
        }
    }
}
