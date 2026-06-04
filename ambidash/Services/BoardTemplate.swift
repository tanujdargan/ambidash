import Foundation
import SwiftData

/// Identifies a starter board layout. Stored on `Board.templateIDRaw` as a raw
/// String (additive-safe). Build C ships the full template set used by the
/// onboarding / board-setup picker; `calm` is the ND-friendly default.
enum BoardTemplateID: String, CaseIterable, Codable, Hashable {
    case calm
    case balanced
    case athlete
    case founder
    case student
    case professional
    case creative
    case minimalist

    /// Human-facing name used for a seeded board's `name` and the picker card.
    var displayName: String {
        switch self {
        case .calm: "Calm"
        case .balanced: "Balanced"
        case .athlete: "Athlete"
        case .founder: "Founder"
        case .student: "Student"
        case .professional: "Professional"
        case .creative: "Creative"
        case .minimalist: "Minimalist"
        }
    }

    /// One-line description shown under the title on a template card.
    var blurb: String {
        switch self {
        case .calm: "Gentle and quiet. One pulse, a few goals, one reflection — no streaks or pressure."
        case .balanced: "A bit of everything: score, vitals, goals, a nudge, and today."
        case .athlete: "Body-first. Vitals up top, streaks, and today's plan front and centre."
        case .founder: "Momentum-first. Composite, goals, history trend, and a mentor nudge."
        case .student: "Focus on goals and the day, with a reflection to close it out."
        case .professional: "Work-first. Today's progress, the day's plan, goals, and the week ahead."
        case .creative: "Idea-first. Capture inbox, your day, wins, and a reflection to close on."
        case .minimalist: "Just the essentials: your pulse and your latest goals."
        }
    }

    /// SF Symbol shown on the template card.
    var sfSymbol: String {
        switch self {
        case .calm: "leaf"
        case .balanced: "circle.grid.2x2"
        case .athlete: "figure.run"
        case .founder: "bolt"
        case .student: "book"
        case .professional: "briefcase"
        case .creative: "paintbrush.pointed"
        case .minimalist: "minus"
        }
    }

    /// Order the templates appear in the picker (Calm first as the default).
    static var pickerOrder: [BoardTemplateID] {
        [.calm, .balanced, .athlete, .founder, .student, .professional, .creative, .minimalist]
    }
}

/// One component placement in a template: which kind, where, how big, and its
/// default config. `BoardTemplate.apply` materializes these into persisted
/// `BoardComponent` rows.
struct ComponentPlacement {
    let kind: ComponentKind
    let section: BoardSection
    let size: CardSize
    let config: String

    init(_ kind: ComponentKind, _ section: BoardSection, _ size: CardSize, config: String = "{}") {
        self.kind = kind
        self.section = section
        self.size = size
        self.config = config
    }
}

enum BoardTemplate {
    /// The ordered component set for a template. `calm` is the ND-friendly default:
    /// composite + identity line in the top, a short Today(3) + Latest goals + ONE
    /// reflection prompt in the body, and deliberately NO streaks / screen-time
    /// pressure surfaces.
    static func placements(for id: BoardTemplateID) -> [ComponentPlacement] {
        switch id {
        case .calm:
            return [
                // Quiet hero: one pulse + who today is shaping you into.
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.identityLine, .top, .full),
                // Gentle body: an always-there capture inbox (the validated #1
                // need — dump a thought in <2s, triage later or never), today as a
                // spatial block timeline (current block highlighted, a live
                // countdown), three latest goals, one reflection prompt to close on.
                // No streaks, no screen-time.
                ComponentPlacement(.captureInbox, .body, .full),
                ComponentPlacement(.dailyTimeline, .body, .full),
                ComponentPlacement(.latestGoals, .body, .full),
                ComponentPlacement(.reflectionPrompt, .body, .full),
            ]

        case .balanced:
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.wakeAdjust, .body, .full),
                ComponentPlacement(.stickyGoals, .body, .full),
                ComponentPlacement(.goalVitals, .body, .full),
                ComponentPlacement(.categories, .body, .full),
                ComponentPlacement(.captureInbox, .body, .full),
                ComponentPlacement(.vitalsGrid, .body, .full),
                ComponentPlacement(.todayProgress, .body, .full),
                ComponentPlacement(.weekAhead, .body, .full),
                ComponentPlacement(.dailyTimeline, .body, .full),
                ComponentPlacement(.latestGoals, .body, .full),
                ComponentPlacement(.mentorCard, .body, .full),
                ComponentPlacement(.identityLine, .body, .full),
            ]

        case .athlete:
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.vitalsGrid, .body, .full),
                ComponentPlacement(.streaks, .body, .medium),
                ComponentPlacement(.todayNarrow, .body, .medium),
                ComponentPlacement(.latestGoals, .body, .full),
            ]

        case .founder:
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.latestGoals, .body, .full),
                ComponentPlacement(.sparklineHistory, .body, .large),
                ComponentPlacement(.mentorCard, .body, .full),
                ComponentPlacement(.todayNarrow, .body, .medium),
            ]

        case .student:
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.latestGoals, .body, .full),
                ComponentPlacement(.todayNarrow, .body, .medium),
                ComponentPlacement(.reflectionPrompt, .body, .full),
            ]

        case .professional:
            // Work-first momentum: pulse up top, then today's completion, the day's
            // plan, goals, and a look at the week's deadlines.
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.todayProgress, .body, .full),
                ComponentPlacement(.dailyTimeline, .body, .full),
                ComponentPlacement(.latestGoals, .body, .full),
                ComponentPlacement(.weekAhead, .body, .full),
                ComponentPlacement(.mentorCard, .body, .full),
            ]

        case .creative:
            // Idea-first and low-pressure: pulse, an always-there capture inbox, the
            // day, evidence of what you made (wins), and a reflection to close on.
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.captureInbox, .body, .full),
                ComponentPlacement(.dailyTimeline, .body, .full),
                ComponentPlacement(.winsWall, .body, .full),
                ComponentPlacement(.reflectionPrompt, .body, .full),
                ComponentPlacement(.identityLine, .body, .full),
            ]

        case .minimalist:
            return [
                ComponentPlacement(.compositeScore, .top, .full),
                ComponentPlacement(.latestGoals, .body, .full),
            ]
        }
    }

    /// Materializes a template's placements onto a freshly-inserted `Board`,
    /// creating one persisted `BoardComponent` per placement with gapped
    /// per-section `sortIndex` (0,10,20…). Does NOT insert the board or save — the
    /// caller owns the board's lifecycle. Pure SwiftData so it lives in the shared
    /// layer and compiles into both targets.
    @MainActor
    static func apply(_ id: BoardTemplateID, to board: Board, context: ModelContext) {
        var perSectionIndex: [BoardSection: Int] = [:]
        for placement in placements(for: id) {
            let next = perSectionIndex[placement.section, default: 0]
            perSectionIndex[placement.section] = next + 10
            let component = BoardComponent(
                kindRaw: placement.kind.rawValue,
                sectionRaw: placement.section.rawValue,
                sortIndex: next,
                isVisible: true,
                sizeRaw: placement.size.rawValue,
                configJSON: placement.config
            )
            component.board = board
            context.insert(component)
        }
    }
}
