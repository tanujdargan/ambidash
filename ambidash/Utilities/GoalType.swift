import SwiftUI

/// Classifies *how* a goal is pursued and judged, which drives decomposition,
/// the kind of daily/weekly action it surfaces, and how progress is scored.
/// String-raw enum backing `Goal.goalTypeRaw`, mirroring `GoalHorizon`.
enum GoalType: String, CaseIterable, Codable, Identifiable {
    /// Daily-ish identity behavior judged by adherence (e.g. sleep, journal).
    case habit
    /// An N-times-per-week practice (e.g. lift 3x/week) judged by weekly cadence.
    case recurring
    /// A multi-step effort toward a deliverable, advanced by next steps.
    case project
    /// A single dated checkpoint, binary done/not-done.
    case milestone
    /// A number that climbs toward a target; usually pairs with measurable fields.
    case accumulation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .habit: "Habit"
        case .recurring: "Recurring"
        case .project: "Project"
        case .milestone: "Milestone"
        case .accumulation: "Accumulation"
        }
    }

    /// Short explanation of how this type decomposes and how it is measured.
    var detail: String {
        switch self {
        case .habit: "A daily identity behavior. Judged by how consistently you show up."
        case .recurring: "A practice you repeat N times a week. Judged by weekly cadence."
        case .project: "A multi-step effort toward a deliverable. Advanced one step at a time."
        case .milestone: "A single dated checkpoint. Either done or not yet done."
        case .accumulation: "A number that climbs toward a target. Move it a little each time."
        }
    }

    var icon: String {
        switch self {
        case .habit: "repeat.circle.fill"
        case .recurring: "calendar.badge.clock"
        case .project: "list.bullet.rectangle.fill"
        case .milestone: "flag.checkered"
        case .accumulation: "chart.line.uptrend.xyaxis"
        }
    }

    /// Whether this type is judged by cadence/adherence rather than a deliverable
    /// or a climbing number. Habit and recurring goals are habitual.
    var isHabitual: Bool {
        switch self {
        case .habit, .recurring: true
        case .project, .milestone, .accumulation: false
        }
    }
}
