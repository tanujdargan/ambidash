import SwiftUI

/// Static metadata for one `ComponentKind`: how it presents in the (future)
/// add-menu and how it defaults onto a board. The registry is the SINGLE seam —
/// persistence, add-menu, editor, and renderer all read from here.
struct ComponentDescriptor {
    let kind: ComponentKind
    let title: String
    let sfSymbol: String
    let category: ComponentCategory
    let blurb: String
    let defaultSection: BoardSection
    let supportedSizes: [CardSize]
    let defaultConfig: String
    /// Single-instance components (e.g. compositeScore) — the add-menu disables a
    /// second copy.
    let isSingleton: Bool
    /// Whether this kind exposes per-instance options in `ComponentConfigSheet`
    /// (e.g. vitalsGrid → which dimensions; todayNarrow → row count). Defaults to
    /// false; non-configurable kinds show no "Configure" affordance in edit mode.
    var isConfigurable: Bool = false
}

/// The component registry: descriptor lookup + the `@ViewBuilder` render factory.
/// Renderers are pure functions of injected `BoardData` (no per-component @Query)
/// and reuse the existing dashboard surfaces + shared card chrome so ALL current
/// behavior is preserved.
enum ComponentRegistry {

    // MARK: - Descriptors

    /// Descriptor for every known kind. `.unknown` resolves to the unavailable
    /// card and is intentionally excluded from the add-menu set.
    static let descriptors: [ComponentKind: ComponentDescriptor] = {
        var map: [ComponentKind: ComponentDescriptor] = [:]
        for d in allDescriptors { map[d.kind] = d }
        return map
    }()

    /// All add-menu-eligible descriptors, in a sensible display order.
    static let allDescriptors: [ComponentDescriptor] = [
        ComponentDescriptor(
            kind: .compositeScore,
            title: "Composite Score",
            sfSymbol: "gauge.with.dots.needle.50percent",
            category: .overview,
            blurb: "Your single life pulse with a recent trend sparkline.",
            defaultSection: .top,
            supportedSizes: [.full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .vitalsGrid,
            title: "Vitals",
            sfSymbol: "circle.grid.3x3",
            category: .metrics,
            blurb: "Arc gauges for each life dimension you care about.",
            defaultSection: .body,
            supportedSizes: [.medium, .large, .full],
            defaultConfig: "{}",
            isSingleton: false,
            isConfigurable: true
        ),
        ComponentDescriptor(
            kind: .sparklineHistory,
            title: "History",
            sfSymbol: "chart.xyaxis.line",
            category: .metrics,
            blurb: "A wider sparkline of your recent composite history.",
            defaultSection: .body,
            supportedSizes: [.medium, .large],
            defaultConfig: "{}",
            isSingleton: false
        ),
        ComponentDescriptor(
            kind: .latestGoals,
            title: "Latest Goals",
            sfSymbol: "flag",
            category: .goals,
            blurb: "The goals you've touched most recently.",
            defaultSection: .body,
            supportedSizes: [.large, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .todayNarrow,
            title: "Today, Narrow",
            sfSymbol: "clock",
            category: .daily,
            blurb: "A tight view of your next few planned actions.",
            defaultSection: .body,
            supportedSizes: [.medium],
            defaultConfig: "{}",
            isSingleton: true,
            isConfigurable: true
        ),
        ComponentDescriptor(
            kind: .mentorCard,
            title: "Mentor",
            sfSymbol: "quote.bubble",
            category: .insights,
            blurb: "One surfaced insight, AI or local pattern.",
            defaultSection: .body,
            supportedSizes: [.medium, .large, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .identityLine,
            title: "Identity Line",
            sfSymbol: "person.fill.viewfinder",
            category: .reflection,
            blurb: "Who today's work is shaping you into.",
            defaultSection: .body,
            supportedSizes: [.full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .reflectionPrompt,
            title: "Reflection Prompt",
            sfSymbol: "square.and.pencil",
            category: .reflection,
            blurb: "A gentle question to close the day with.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .dailyTimeline,
            title: "Day Timeline",
            sfSymbol: "calendar.badge.clock",
            category: .daily,
            blurb: "Today as duration-sized blocks — current highlighted, with a live countdown.",
            defaultSection: .body,
            supportedSizes: [.large, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .streaks,
            title: "Streaks",
            sfSymbol: "flame",
            category: .daily,
            blurb: "Active streaks and which ones are at risk today.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .todayProgress,
            title: "Today's Progress",
            sfSymbol: "checkmark.circle",
            category: .daily,
            blurb: "How many of today's blocks you've finished — the done-count + a progress ring.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .weekAhead,
            title: "Week Ahead",
            sfSymbol: "calendar",
            category: .daily,
            blurb: "The next 7 days with their dated milestone deadlines — see what's coming.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .stickyGoals,
            title: "Sticky Notes",
            sfSymbol: "pin",
            category: .goals,
            blurb: "Pinned goals kept always-visible but glanceable — a sticky note for what matters.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .categories,
            title: "Categories",
            sfSymbol: "square.grid.2x2",
            category: .goals,
            blurb: "Your goals grouped into categories derived from what you're working on, with subgoal counts.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .wakeAdjust,
            title: "Wake Check",
            sfSymbol: "sunrise",
            category: .daily,
            blurb: "A gentle nudge to re-adjust when your wake time drifts from your goal.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .captureInbox,
            title: "Capture Inbox",
            sfSymbol: "tray",
            category: .daily,
            blurb: "Recent thoughts you dumped — triage one tap at a time, no pressure.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .energyCheckin,
            title: "Energy",
            sfSymbol: "bolt.heart",
            category: .daily,
            blurb: "A one-tap energy check-in — never a judgment, always optional.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .patternCheckIn,
            title: "Gentle Check-in",
            sfSymbol: "sparkles",
            category: .insights,
            blurb: "Notices how your days actually go and offers a kinder plan — never a verdict.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .closingRitual,
            title: "Close the Day",
            sfSymbol: "moon.stars",
            category: .reflection,
            blurb: "A calm end-of-day wrap — celebrate what you did and pick tomorrow's one thing.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .focusSession,
            title: "Focus",
            sfSymbol: "timer",
            category: .daily,
            blurb: "A calm focus timer for your current block or a quick session — gentle finish, optional soundscape, a companion alongside you.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
        ComponentDescriptor(
            kind: .winsWall,
            title: "Wins",
            sfSymbol: "rosette",
            category: .reflection,
            blurb: "Evidence of what you actually did — partials count, never a deficit. With a gentle weekly review.",
            defaultSection: .body,
            supportedSizes: [.medium, .full],
            defaultConfig: "{}",
            isSingleton: true
        ),
    ]

    static func descriptor(for kind: ComponentKind) -> ComponentDescriptor? {
        descriptors[kind]
    }

    // MARK: - Render factory

    /// Render the view for a component. Switches on the resolved kind and falls
    /// back to `UnavailableComponentCard` for `.unknown` (or any kind without a
    /// renderer). `onTapScore` carries the existing tap-for-breakdown behavior up
    /// to the board's NavigationStack host.
    @MainActor
    @ViewBuilder
    static func render(
        _ component: BoardComponent,
        boardData: BoardData,
        onTapScore: @escaping (ScoreBreakdownTarget) -> Void
    ) -> some View {
        switch component.kind {
        case .compositeScore:
            CompositeScoreComponent(boardData: boardData, onTapScore: onTapScore)
        case .vitalsGrid:
            VitalsGridComponent(boardData: boardData, config: ComponentConfig.vitals(from: component.configJSON), onTapScore: onTapScore)
        case .sparklineHistory:
            SparklineHistoryComponent(boardData: boardData)
        case .latestGoals:
            LatestGoalsComponent(boardData: boardData)
        case .todayNarrow:
            TodayNarrowComponent(boardData: boardData, config: ComponentConfig.today(from: component.configJSON))
        case .dailyTimeline:
            DailyTimelineComponent(boardData: boardData)
        case .streaks:
            StreaksComponent(boardData: boardData)
        case .todayProgress:
            TodayProgressComponent(boardData: boardData)
        case .weekAhead:
            WeekAheadComponent()
        case .stickyGoals:
            StickyGoalsComponent()
        case .categories:
            GoalCategoriesComponent()
        case .wakeAdjust:
            WakeAdjustComponent()
        case .captureInbox:
            // The one inherently-dynamic component: it owns a small @Query for the
            // recent inbox (mutated by quick-add/triage), so it is intentionally NOT
            // fed from the static BoardData snapshot.
            CaptureInboxComponent()
        case .energyCheckin:
            // Owns a small @Query for today's check-ins (mutated by tapping), so it
            // is intentionally NOT fed from the static BoardData snapshot.
            EnergyCheckinComponent()
        case .patternCheckIn:
            // Owns small @Querys for recent actuals/check-ins to derive the gentle
            // offer; reads prefs/goals from BoardData. Renders nothing when there's no
            // persistent pattern worth surfacing.
            PatternCheckInComponent(boardData: boardData)
        case .closingRitual:
            // Owns small @Querys for today's plan / actuals / reflection to build
            // its preview + the ritual sheet; mutates the store on save, so it is
            // intentionally NOT fed from the static BoardData snapshot.
            ClosingRitualComponent()
        case .focusSession:
            // Reads the current/next block from the static BoardData snapshot; the
            // running session is ephemeral (@State). When a session finishes against
            // a block it may fold an inferred ActualEvent into the store, so it also
            // takes the modelContext from the environment internally.
            FocusSessionComponent(boardData: boardData)
        case .winsWall:
            // Owns small @Querys for recent ActualEvents + DailyPlans to derive wins via
            // WinsService (no new @Model). Reads nothing it mutates; the weekly review
            // sheet is read-only too.
            WinsWallComponent()
        case .mentorCard:
            MentorComponent(boardData: boardData)
        case .identityLine:
            IdentityLineComponent(boardData: boardData)
        case .reflectionPrompt:
            ReflectionPromptComponent(boardData: boardData)
        case .unknown:
            UnavailableComponentCard(kindRaw: component.kindRaw)
        }
    }
}
