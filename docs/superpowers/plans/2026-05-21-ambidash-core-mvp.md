# ambidash Core MVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working iOS app with onboarding assessments, goal management, and a self-awareness dashboard — the foundation everything else layers onto.

**Architecture:** Pure SwiftUI app with SwiftData persistence and @Observable view models. Onboarding flows are a NavigationStack-driven multi-step wizard. Dashboard reads computed scores from local data. No backend, no integrations, no AI in this plan — those are separate plans.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, iOS 17+

**This is Plan 1 of 6:**
1. **Core MVP** (this plan) — Foundation, onboarding, goals, dashboard
2. Integration Layer — HealthKit, EventKit, DeviceActivity, normalization
3. Daily Plan + Reflection — Plan engine, action tracking, reflection flows
4. Backend + AI Mentor — Vapor server, Claude API, mentor roles
5. Retention + Payments — Notifications, streaks, guilt nudges, StoreKit 2
6. External Integrations + Polish — Notion, Obsidian, diminishing scaffolding

---

## File Structure

```
ambidash/
├── ambidash/
│   ├── App/
│   │   ├── AmbidashApp.swift              — App entry, ModelContainer setup
│   │   ├── RootView.swift                 — Routes between onboarding and main app
│   │   └── MainTabView.swift              — Tab bar (Dashboard, Today, Goals, Reflect)
│   ├── Models/
│   │   ├── UserProfile.swift              — @Model: name, age, lifeStage, scaffoldLevel
│   │   ├── CoreAssessment.swift           — @Model: cognitive style, ADHD/anxiety scores, values
│   │   ├── WorkStylePreference.swift      — @Model: plan format, notif intensity, max actions
│   │   ├── Goal.swift                     — @Model: title, domain, priority, status, neglect tracking
│   │   ├── DomainAssessment.swift         — @Model: domain-specific assessment answers
│   │   ├── GoalProgress.swift             — @Model: daily score per goal, trend, status color
│   │   ├── Streak.swift                   — @Model: current/best count per goal
│   │   ├── IntegrationSnapshot.swift      — @Model: daily rollup (stub for now, populated in Plan 2)
│   │   ├── DailyPlan.swift                — @Model: stub for Plan 3
│   │   ├── PlannedAction.swift            — @Model: stub for Plan 3
│   │   ├── Reflection.swift               — @Model: stub for Plan 3
│   │   └── MentorFeedback.swift           — @Model: stub for Plan 4
│   ├── Services/
│   │   ├── PulseScoreCalculator.swift     — Computes composite pulse score from goals + snapshots
│   │   ├── DimensionScoreCalculator.swift — Computes Body/Mind/Focus/Social/Growth scores
│   │   └── GoalHealthService.swift        — Determines goal status colors, neglect detection
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── WelcomeView.swift          — First screen, start onboarding CTA
│   │   │   ├── AssessmentFlowView.swift   — NavigationStack container for assessment steps
│   │   │   ├── AssessmentQuestionView.swift — Reusable single-question view
│   │   │   ├── GoalDeclarationView.swift  — Pick which goals to pursue
│   │   │   ├── WorkStylePickerView.swift  — Choose plan format preference
│   │   │   └── OnboardingCompleteView.swift — Summary + transition to main app
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift        — Main dashboard screen
│   │   │   ├── PulseScoreView.swift       — Circular score ring
│   │   │   ├── DimensionBarsView.swift    — Five dimension progress bars
│   │   │   ├── QuickStatsView.swift       — Three key numbers row
│   │   │   ├── GoalStripView.swift        — Horizontal scrolling goal chips
│   │   │   └── InsightCardView.swift      — AI insight placeholder card
│   │   └── Goals/
│   │       ├── GoalListView.swift         — All goals list (Goals tab)
│   │       ├── GoalDetailView.swift       — Single goal deep dive
│   │       └── AddGoalView.swift          — Add new goal + trigger assessment
│   └── Utilities/
│       ├── AssessmentQuestion.swift       — Question definition model (not persisted)
│       ├── GoalDomain.swift               — Enum of goal domains
│       ├── GoalStatus.swift               — Enum: onTrack, needsAttention, slipping
│       ├── PlanFormat.swift               — Enum: focusBlocks, singleAction, priorityList
│       └── LifeDimension.swift            — Enum: body, mind, focus, social, growth
├── ambidashTests/
│   ├── Models/
│   │   ├── GoalTests.swift                — Goal model behavior
│   │   └── CoreAssessmentTests.swift      — Assessment model behavior
│   ├── Services/
│   │   ├── PulseScoreCalculatorTests.swift
│   │   ├── DimensionScoreCalculatorTests.swift
│   │   └── GoalHealthServiceTests.swift
│   └── Utilities/
│       └── GoalDomainTests.swift
```

---

### Task 1: Create Xcode Project

**Files:**
- Create: Xcode project `ambidash` with test target

- [ ] **Step 1: Create the project**

Open Xcode → File → New → Project → iOS → App
- Product Name: `ambidash`
- Team: your dev team
- Organization Identifier: your bundle id prefix
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData (check this — it scaffolds ModelContainer)
- Include Tests: check (creates `ambidashTests` target)

- [ ] **Step 2: Set deployment target**

In project settings → General → Minimum Deployments → set to iOS 17.0

- [ ] **Step 3: Enable Swift Testing in test target**

In `ambidashTests`, Xcode should default to Swift Testing for new projects on Xcode 16+. Verify the test target has `import Testing` available by creating a trivial test:

```swift
// ambidashTests/SanityTests.swift
import Testing

@Test func projectSetupWorks() {
    #expect(true)
}
```

- [ ] **Step 4: Run the test**

Run: `Cmd+U` in Xcode or `xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: 1 test passes

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: initialize Xcode project with SwiftData and Swift Testing"
```

---

### Task 2: Utility Enums

**Files:**
- Create: `ambidash/Utilities/GoalDomain.swift`
- Create: `ambidash/Utilities/GoalStatus.swift`
- Create: `ambidash/Utilities/PlanFormat.swift`
- Create: `ambidash/Utilities/LifeDimension.swift`
- Test: `ambidashTests/Utilities/GoalDomainTests.swift`

- [ ] **Step 1: Write test for GoalDomain**

```swift
// ambidashTests/Utilities/GoalDomainTests.swift
import Testing
@testable import ambidash

@Test func goalDomainHasExpectedCases() {
    let allCases = GoalDomain.allCases
    #expect(allCases.count == 7)
    #expect(GoalDomain.fitness.displayName == "Fitness & Body")
    #expect(GoalDomain.fitness.dimension == .body)
}

@Test func goalDomainMapsToCorrectDimension() {
    #expect(GoalDomain.fitness.dimension == .body)
    #expect(GoalDomain.cognitive.dimension == .mind)
    #expect(GoalDomain.screenTime.dimension == .focus)
    #expect(GoalDomain.social.dimension == .social)
    #expect(GoalDomain.career.dimension == .growth)
    #expect(GoalDomain.language.dimension == .mind)
    #expect(GoalDomain.financial.dimension == .growth)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: FAIL — `GoalDomain` not defined

- [ ] **Step 3: Implement all enums**

```swift
// ambidash/Utilities/LifeDimension.swift
import Foundation

enum LifeDimension: String, CaseIterable, Codable {
    case body, mind, focus, social, growth

    var displayName: String {
        switch self {
        case .body: "Body"
        case .mind: "Mind"
        case .focus: "Focus"
        case .social: "Social"
        case .growth: "Growth"
        }
    }

    var color: String {
        switch self {
        case .body: "green"
        case .mind: "purple"
        case .focus: "blue"
        case .social: "pink"
        case .growth: "orange"
        }
    }
}
```

```swift
// ambidash/Utilities/GoalDomain.swift
import Foundation

enum GoalDomain: String, CaseIterable, Codable, Identifiable {
    case fitness, cognitive, social, career, language, screenTime, financial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitness: "Fitness & Body"
        case .cognitive: "Cognitive & Learning"
        case .social: "Social & Communication"
        case .career: "Career & Building"
        case .language: "Language"
        case .screenTime: "Screen Time"
        case .financial: "Financial"
        }
    }

    var dimension: LifeDimension {
        switch self {
        case .fitness: .body
        case .cognitive, .language: .mind
        case .screenTime: .focus
        case .social: .social
        case .career, .financial: .growth
        }
    }

    var icon: String {
        switch self {
        case .fitness: "figure.run"
        case .cognitive: "brain.head.profile"
        case .social: "person.2"
        case .career: "briefcase"
        case .language: "character.bubble"
        case .screenTime: "iphone"
        case .financial: "dollarsign.circle"
        }
    }
}
```

```swift
// ambidash/Utilities/GoalStatus.swift
import SwiftUI

enum GoalStatus: String, Codable {
    case onTrack, needsAttention, slipping, paused

    var color: Color {
        switch self {
        case .onTrack: .green
        case .needsAttention: .orange
        case .slipping: .red
        case .paused: .gray
        }
    }

    var label: String {
        switch self {
        case .onTrack: "On Track"
        case .needsAttention: "Needs Attention"
        case .slipping: "Slipping"
        case .paused: "Paused"
        }
    }
}
```

```swift
// ambidash/Utilities/PlanFormat.swift
import Foundation

enum PlanFormat: String, CaseIterable, Codable, Identifiable {
    case focusBlocks, singleAction, priorityList

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focusBlocks: "Focus Blocks"
        case .singleAction: "Single Next Action"
        case .priorityList: "Priority List"
        }
    }

    var description: String {
        switch self {
        case .focusBlocks: "Time-slotted actions with reasoning. Best for structured learners."
        case .singleAction: "One action at a time. Best if you get overwhelmed easily."
        case .priorityList: "Ranked list, no strict times. Best if you're self-directed."
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add ambidash/Utilities/ ambidashTests/Utilities/
git commit -m "feat: add core utility enums (GoalDomain, GoalStatus, PlanFormat, LifeDimension)"
```

---

### Task 3: SwiftData Models — Core Entities

**Files:**
- Create: `ambidash/Models/UserProfile.swift`
- Create: `ambidash/Models/CoreAssessment.swift`
- Create: `ambidash/Models/WorkStylePreference.swift`
- Create: `ambidash/Models/Goal.swift`
- Create: `ambidash/Models/DomainAssessment.swift`
- Create: `ambidash/Models/GoalProgress.swift`
- Create: `ambidash/Models/Streak.swift`
- Test: `ambidashTests/Models/GoalTests.swift`
- Test: `ambidashTests/Models/CoreAssessmentTests.swift`

- [ ] **Step 1: Write test for Goal model**

```swift
// ambidashTests/Models/GoalTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func goalTracksNeglectDays() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)
    #expect(goal.neglectDays == 0)
    #expect(goal.status == .onTrack)
}

@Test func goalComputesNeglectFromLastProgress() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
    #expect(goal.neglectDays == 5)
}

@Test func goalStatusDegrades() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
    #expect(goal.computedStatus == .onTrack)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
    #expect(goal.computedStatus == .needsAttention)

    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
    #expect(goal.computedStatus == .slipping)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `Goal` not defined

- [ ] **Step 3: Implement all models**

```swift
// ambidash/Models/UserProfile.swift
import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var age: Int
    var lifeStage: String
    var timezone: String
    var scaffoldLevel: Int
    var createdAt: Date
    var onboardingComplete: Bool

    @Relationship(deleteRule: .cascade) var coreAssessment: CoreAssessment?
    @Relationship(deleteRule: .cascade) var workStylePreference: WorkStylePreference?
    @Relationship(deleteRule: .cascade) var goals: [Goal]

    init(name: String = "", age: Int = 0, lifeStage: String = "student") {
        self.id = UUID()
        self.name = name
        self.age = age
        self.lifeStage = lifeStage
        self.timezone = TimeZone.current.identifier
        self.scaffoldLevel = 3
        self.createdAt = .now
        self.onboardingComplete = false
        self.goals = []
    }
}
```

```swift
// ambidash/Models/CoreAssessment.swift
import Foundation
import SwiftData

@Model
final class CoreAssessment {
    var id: UUID
    var cognitiveStyle: String
    var peakEnergyTime: String
    var overwhelmResponse: String
    var adhdScore: Int
    var anxietyScore: Int
    var sleepQualitySelfRating: Int
    var lifeSatisfaction: [String: Int]
    var topValues: [String]
    var biggestBlocker: String
    var accountabilityPreference: String
    var assessedAt: Date

    var profile: UserProfile?

    init() {
        self.id = UUID()
        self.cognitiveStyle = ""
        self.peakEnergyTime = ""
        self.overwhelmResponse = ""
        self.adhdScore = 0
        self.anxietyScore = 0
        self.sleepQualitySelfRating = 0
        self.lifeSatisfaction = [:]
        self.topValues = []
        self.biggestBlocker = ""
        self.accountabilityPreference = ""
        self.assessedAt = .now
    }
}
```

```swift
// ambidash/Models/WorkStylePreference.swift
import Foundation
import SwiftData

@Model
final class WorkStylePreference {
    var id: UUID
    var planFormat: String
    var streaksEnabled: Bool
    var notificationIntensity: String
    var maxActionsPerDay: Int

    var profile: UserProfile?

    init(planFormat: PlanFormat = .focusBlocks) {
        self.id = UUID()
        self.planFormat = planFormat.rawValue
        self.streaksEnabled = true
        self.notificationIntensity = "moderate"
        self.maxActionsPerDay = 6
    }

    var format: PlanFormat {
        PlanFormat(rawValue: planFormat) ?? .focusBlocks
    }
}
```

```swift
// ambidash/Models/Goal.swift
import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var domainRaw: String
    var priority: Int
    var statusRaw: String
    var createdAt: Date
    var lastProgressDate: Date
    var isActive: Bool

    var profile: UserProfile?
    @Relationship(deleteRule: .cascade) var domainAssessment: DomainAssessment?
    @Relationship(deleteRule: .cascade) var progressEntries: [GoalProgress]
    @Relationship(deleteRule: .cascade) var streak: Streak?

    init(title: String, domain: GoalDomain, priority: Int) {
        self.id = UUID()
        self.title = title
        self.domainRaw = domain.rawValue
        self.priority = priority
        self.statusRaw = GoalStatus.onTrack.rawValue
        self.createdAt = .now
        self.lastProgressDate = .now
        self.isActive = true
        self.progressEntries = []
    }

    var domain: GoalDomain {
        GoalDomain(rawValue: domainRaw) ?? .fitness
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .onTrack }
        set { statusRaw = newValue.rawValue }
    }

    var neglectDays: Int {
        Calendar.current.dateComponents([.day], from: lastProgressDate, to: .now).day ?? 0
    }

    var computedStatus: GoalStatus {
        if !isActive { return .paused }
        let days = neglectDays
        if days <= 3 { return .onTrack }
        if days <= 7 { return .needsAttention }
        return .slipping
    }
}
```

```swift
// ambidash/Models/DomainAssessment.swift
import Foundation
import SwiftData

@Model
final class DomainAssessment {
    var id: UUID
    var domainRaw: String
    var answers: [String: String]
    var assessedAt: Date

    var goal: Goal?

    init(domain: GoalDomain) {
        self.id = UUID()
        self.domainRaw = domain.rawValue
        self.answers = [:]
        self.assessedAt = .now
    }

    var domain: GoalDomain {
        GoalDomain(rawValue: domainRaw) ?? .fitness
    }
}
```

```swift
// ambidash/Models/GoalProgress.swift
import Foundation
import SwiftData

@Model
final class GoalProgress {
    var id: UUID
    var date: Date
    var score: Int
    var trend7d: Int
    var statusColorRaw: String

    var goal: Goal?

    init(score: Int, trend7d: Int = 0, statusColor: GoalStatus = .onTrack) {
        self.id = UUID()
        self.date = .now
        self.score = score
        self.trend7d = trend7d
        self.statusColorRaw = statusColor.rawValue
    }
}
```

```swift
// ambidash/Models/Streak.swift
import Foundation
import SwiftData

@Model
final class Streak {
    var id: UUID
    var currentCount: Int
    var bestCount: Int
    var lastActiveDate: Date

    var goal: Goal?

    init() {
        self.id = UUID()
        self.currentCount = 0
        self.bestCount = 0
        self.lastActiveDate = .now
    }

    var isAlive: Bool {
        Calendar.current.isDateInToday(lastActiveDate) ||
        Calendar.current.isDateInYesterday(lastActiveDate)
    }

    func recordActivity() {
        if Calendar.current.isDateInToday(lastActiveDate) { return }
        if Calendar.current.isDateInYesterday(lastActiveDate) {
            currentCount += 1
        } else {
            currentCount = 1
        }
        if currentCount > bestCount {
            bestCount = currentCount
        }
        lastActiveDate = .now
    }
}
```

- [ ] **Step 4: Create stub models for future plans**

```swift
// ambidash/Models/IntegrationSnapshot.swift
import Foundation
import SwiftData

@Model
final class IntegrationSnapshot {
    var id: UUID
    var date: Date
    var sleepHours: Double
    var sleepScore: Int
    var steps: Int
    var workoutCount: Int
    var screenTimeHours: Double
    var screenCategories: [String: Double]
    var pickups: Int
    var calendarFreeMinutes: Int

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.sleepHours = 0
        self.sleepScore = 0
        self.steps = 0
        self.workoutCount = 0
        self.screenTimeHours = 0
        self.screenCategories = [:]
        self.pickups = 0
        self.calendarFreeMinutes = 0
    }
}
```

```swift
// ambidash/Models/DailyPlan.swift
import Foundation
import SwiftData

@Model
final class DailyPlan {
    var id: UUID
    var date: Date
    var formatRaw: String
    var actionCount: Int
    var regenerated: Bool
    var generatedAt: Date

    @Relationship(deleteRule: .cascade) var actions: [PlannedAction]

    init(date: Date = .now, format: PlanFormat = .focusBlocks) {
        self.id = UUID()
        self.date = date
        self.formatRaw = format.rawValue
        self.actionCount = 0
        self.regenerated = false
        self.generatedAt = .now
        self.actions = []
    }
}
```

```swift
// ambidash/Models/PlannedAction.swift
import Foundation
import SwiftData

@Model
final class PlannedAction {
    var id: UUID
    var title: String
    var whyReasoning: String
    var timeSlot: String
    var durationMinutes: Int
    var statusRaw: String
    var completedAt: Date?
    var skipReason: String?

    var plan: DailyPlan?

    init(title: String, why: String = "", timeSlot: String = "", duration: Int = 30) {
        self.id = UUID()
        self.title = title
        self.whyReasoning = why
        self.timeSlot = timeSlot
        self.durationMinutes = duration
        self.statusRaw = "pending"
        self.completedAt = nil
        self.skipReason = nil
    }
}
```

```swift
// ambidash/Models/Reflection.swift
import Foundation
import SwiftData

@Model
final class Reflection {
    var id: UUID
    var date: Date
    var typeRaw: String
    var mood: String
    var blockers: [String]
    var freeformText: String

    init(date: Date = .now, type: String = "daily") {
        self.id = UUID()
        self.date = date
        self.typeRaw = type
        self.mood = ""
        self.blockers = []
        self.freeformText = ""
    }
}
```

```swift
// ambidash/Models/MentorFeedback.swift
import Foundation
import SwiftData

@Model
final class MentorFeedback {
    var id: UUID
    var role: String
    var content: String
    var trigger: String
    var createdAt: Date
    var quotaCost: Int

    init(role: String, content: String, trigger: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.trigger = trigger
        self.createdAt = .now
        self.quotaCost = 1
    }
}
```

- [ ] **Step 5: Write test for CoreAssessment**

```swift
// ambidashTests/Models/CoreAssessmentTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func coreAssessmentInitializesWithDefaults() {
    let assessment = CoreAssessment()
    #expect(assessment.adhdScore == 0)
    #expect(assessment.topValues.isEmpty)
    #expect(assessment.cognitiveStyle == "")
}
```

- [ ] **Step 6: Run all tests**

Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add ambidash/Models/ ambidashTests/Models/
git commit -m "feat: add all SwiftData models (core + stubs for future plans)"
```

---

### Task 4: App Entry + ModelContainer

**Files:**
- Modify: `ambidash/App/AmbidashApp.swift` (Xcode-generated, rename if needed)
- Create: `ambidash/App/MainTabView.swift`

- [ ] **Step 1: Set up ModelContainer with all models**

```swift
// ambidash/App/AmbidashApp.swift
import SwiftUI
import SwiftData

@main
struct AmbidashApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            UserProfile.self,
            CoreAssessment.self,
            WorkStylePreference.self,
            Goal.self,
            DomainAssessment.self,
            GoalProgress.self,
            Streak.self,
            IntegrationSnapshot.self,
            DailyPlan.self,
            PlannedAction.self,
            Reflection.self,
            MentorFeedback.self,
        ])
    }
}
```

- [ ] **Step 2: Create RootView that routes between onboarding and main app**

```swift
// ambidash/App/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]

    private var hasCompletedOnboarding: Bool {
        profiles.first?.onboardingComplete ?? false
    }

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
```

- [ ] **Step 3: Create tab bar shell**

```swift
// ambidash/App/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "circle.grid.3x3") {
                DashboardView()
            }
            Tab("Today", systemImage: "play.fill") {
                Text("Today — Plan 3")
            }
            Tab("Goals", systemImage: "target") {
                GoalListView()
            }
            Tab("Reflect", systemImage: "pencil.line") {
                Text("Reflect — Plan 3")
            }
        }
    }
}
```

- [ ] **Step 4: Build and run in simulator**

Run: `Cmd+R` in Xcode
Expected: App launches showing WelcomeView (which doesn't exist yet — will show a build error). Create a temporary placeholder:

```swift
// ambidash/Views/Onboarding/WelcomeView.swift
import SwiftUI

struct WelcomeView: View {
    var body: some View {
        Text("Welcome to ambidash")
    }
}
```

Also create placeholders for the tab destinations:

```swift
// ambidash/Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    var body: some View {
        Text("Dashboard — coming soon")
    }
}
```

```swift
// ambidash/Views/Goals/GoalListView.swift
import SwiftUI

struct GoalListView: View {
    var body: some View {
        Text("Goals — coming soon")
    }
}
```

Run again. Expected: App launches, shows "Welcome to ambidash"

- [ ] **Step 5: Commit**

```bash
git add ambidash/App/ ambidash/Views/
git commit -m "feat: app entry with ModelContainer, root routing, and tab bar shell"
```

---

### Task 5: Assessment Question Framework

**Files:**
- Create: `ambidash/Utilities/AssessmentQuestion.swift`

- [ ] **Step 1: Define the question model**

This is not a SwiftData model — it's a plain struct defining the assessment content.

```swift
// ambidash/Utilities/AssessmentQuestion.swift
import Foundation

struct AssessmentQuestion: Identifiable {
    let id: String
    let text: String
    let subtitle: String
    let options: [AssessmentOption]
    let category: String
    let multiSelect: Bool

    init(
        id: String,
        text: String,
        subtitle: String = "",
        options: [AssessmentOption],
        category: String,
        multiSelect: Bool = false
    ) {
        self.id = id
        self.text = text
        self.subtitle = subtitle
        self.options = options
        self.category = category
        self.multiSelect = multiSelect
    }
}

struct AssessmentOption: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String

    init(id: String, label: String, description: String = "") {
        self.id = id
        self.label = label
        self.description = description
    }
}

enum CoreAssessmentQuestions {
    static let all: [AssessmentQuestion] = [
        // Cognitive & Work Style
        AssessmentQuestion(
            id: "focus_style",
            text: "How do you focus best?",
            subtitle: "There's no wrong answer — this helps us plan your day",
            options: [
                AssessmentOption(id: "deep_blocks", label: "Deep blocks", description: "Long uninterrupted sessions"),
                AssessmentOption(id: "pomodoro", label: "Pomodoro", description: "Timed bursts with breaks"),
                AssessmentOption(id: "task_switching", label: "Task switching", description: "Jumping between tasks keeps you fresh"),
                AssessmentOption(id: "flow_state", label: "Flow state", description: "You can't predict it, but when it hits, you ride it"),
            ],
            category: "cognitive"
        ),
        AssessmentQuestion(
            id: "peak_energy",
            text: "When's your peak energy?",
            subtitle: "We'll schedule your hardest tasks here",
            options: [
                AssessmentOption(id: "morning", label: "Morning", description: "Before noon"),
                AssessmentOption(id: "afternoon", label: "Afternoon", description: "1pm — 5pm"),
                AssessmentOption(id: "evening", label: "Evening", description: "After 6pm"),
                AssessmentOption(id: "inconsistent", label: "Inconsistent", description: "It varies day to day"),
            ],
            category: "cognitive"
        ),
        AssessmentQuestion(
            id: "overwhelm_response",
            text: "When everything piles up, what do you do?",
            options: [
                AssessmentOption(id: "shutdown", label: "Shut down", description: "Freeze and avoid everything"),
                AssessmentOption(id: "hyperfocus", label: "Hyperfocus on one thing", description: "Pick one and ignore the rest"),
                AssessmentOption(id: "scatter", label: "Scatter", description: "Start five things, finish none"),
            ],
            category: "cognitive"
        ),
        // Self-Awareness Baseline
        AssessmentQuestion(
            id: "adhd_focus",
            text: "How often do you have trouble keeping your attention on tasks?",
            subtitle: "Based on ASRS screening — be honest",
            options: [
                AssessmentOption(id: "never", label: "Never"),
                AssessmentOption(id: "rarely", label: "Rarely"),
                AssessmentOption(id: "sometimes", label: "Sometimes"),
                AssessmentOption(id: "often", label: "Often"),
                AssessmentOption(id: "very_often", label: "Very often"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "adhd_restless",
            text: "How often do you feel restless or fidgety?",
            options: [
                AssessmentOption(id: "never", label: "Never"),
                AssessmentOption(id: "rarely", label: "Rarely"),
                AssessmentOption(id: "sometimes", label: "Sometimes"),
                AssessmentOption(id: "often", label: "Often"),
                AssessmentOption(id: "very_often", label: "Very often"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "anxiety_level",
            text: "Over the last 2 weeks, how often have you felt nervous or on edge?",
            subtitle: "GAD-7 inspired — no judgment",
            options: [
                AssessmentOption(id: "not_at_all", label: "Not at all"),
                AssessmentOption(id: "several_days", label: "Several days"),
                AssessmentOption(id: "more_than_half", label: "More than half the days"),
                AssessmentOption(id: "nearly_every_day", label: "Nearly every day"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "sleep_quality",
            text: "How would you rate your typical sleep?",
            options: [
                AssessmentOption(id: "great", label: "Great", description: "7-9 hrs, wake up refreshed"),
                AssessmentOption(id: "ok", label: "Okay", description: "Could be better, not terrible"),
                AssessmentOption(id: "poor", label: "Poor", description: "Inconsistent or not enough"),
                AssessmentOption(id: "terrible", label: "Terrible", description: "Major sleep problems"),
            ],
            category: "baseline"
        ),
        // Values & Priorities
        AssessmentQuestion(
            id: "top_values",
            text: "Pick your top 3 values",
            subtitle: "These guide how the app prioritizes your goals",
            options: [
                AssessmentOption(id: "health", label: "Health"),
                AssessmentOption(id: "career", label: "Career"),
                AssessmentOption(id: "learning", label: "Learning"),
                AssessmentOption(id: "relationships", label: "Relationships"),
                AssessmentOption(id: "freedom", label: "Freedom"),
                AssessmentOption(id: "creativity", label: "Creativity"),
                AssessmentOption(id: "wealth", label: "Wealth"),
                AssessmentOption(id: "impact", label: "Impact"),
            ],
            category: "values",
            multiSelect: true
        ),
        AssessmentQuestion(
            id: "biggest_blocker",
            text: "What's your biggest blocker right now?",
            options: [
                AssessmentOption(id: "time", label: "Not enough time"),
                AssessmentOption(id: "motivation", label: "Motivation"),
                AssessmentOption(id: "knowledge", label: "Don't know where to start"),
                AssessmentOption(id: "fear", label: "Fear / anxiety"),
                AssessmentOption(id: "habits", label: "Bad habits"),
                AssessmentOption(id: "focus", label: "Can't focus"),
            ],
            category: "values"
        ),
        AssessmentQuestion(
            id: "accountability",
            text: "How do you feel about accountability?",
            subtitle: "This controls how aggressive the app's nudges are",
            options: [
                AssessmentOption(id: "want_it", label: "I want it", description: "Push me hard, call me out"),
                AssessmentOption(id: "moderate", label: "Moderate", description: "Nudge me, don't nag me"),
                AssessmentOption(id: "gentle", label: "Gentle", description: "Suggest, don't pressure"),
            ],
            category: "values"
        ),
    ]
}
```

- [ ] **Step 2: Commit**

```bash
git add ambidash/Utilities/AssessmentQuestion.swift
git commit -m "feat: add assessment question definitions with ASRS and GAD-7 adapted items"
```

---

### Task 6: Onboarding Flow Views

**Files:**
- Modify: `ambidash/Views/Onboarding/WelcomeView.swift`
- Create: `ambidash/Views/Onboarding/AssessmentFlowView.swift`
- Create: `ambidash/Views/Onboarding/AssessmentQuestionView.swift`
- Create: `ambidash/Views/Onboarding/GoalDeclarationView.swift`
- Create: `ambidash/Views/Onboarding/WorkStylePickerView.swift`
- Create: `ambidash/Views/Onboarding/OnboardingCompleteView.swift`

- [ ] **Step 1: Build WelcomeView**

```swift
// ambidash/Views/Onboarding/WelcomeView.swift
import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAssessment = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("ambidash")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Your life, one dashboard.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Text("We'll ask you a few questions to understand how you work, what you care about, and what you want to achieve.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("~5 minutes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    let profile = UserProfile()
                    modelContext.insert(profile)
                    showAssessment = true
                } label: {
                    Text("Let's go")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $showAssessment) {
                AssessmentFlowView()
            }
        }
    }
}
```

- [ ] **Step 2: Build AssessmentQuestionView (reusable)**

```swift
// ambidash/Views/Onboarding/AssessmentQuestionView.swift
import SwiftUI

struct AssessmentQuestionView: View {
    let question: AssessmentQuestion
    @Binding var selectedIds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.bold)

                if !question.subtitle.isEmpty {
                    Text(question.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    let isSelected = selectedIds.contains(option.id)

                    Button {
                        if question.multiSelect {
                            if isSelected {
                                selectedIds.remove(option.id)
                            } else {
                                selectedIds.insert(option.id)
                            }
                        } else {
                            selectedIds = [option.id]
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)

                                if !option.description.isEmpty {
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 3: Build AssessmentFlowView**

```swift
// ambidash/Views/Onboarding/AssessmentFlowView.swift
import SwiftUI
import SwiftData

struct AssessmentFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var currentIndex = 0
    @State private var answers: [String: Set<String>] = [:]
    @State private var showGoalDeclaration = false

    private let questions = CoreAssessmentQuestions.all

    private var profile: UserProfile? { profiles.first }

    private var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    private var canAdvance: Bool {
        guard currentIndex < questions.count else { return false }
        let q = questions[currentIndex]
        let selected = answers[q.id] ?? []
        if q.multiSelect {
            return selected.count >= 1
        }
        return !selected.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: progress)
                .padding(.horizontal)
                .padding(.top, 8)

            Text("\(currentIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ScrollView {
                if currentIndex < questions.count {
                    AssessmentQuestionView(
                        question: questions[currentIndex],
                        selectedIds: binding(for: questions[currentIndex].id)
                    )
                    .id(currentIndex)
                    .padding(.top, 24)
                }
            }

            HStack(spacing: 16) {
                if currentIndex > 0 {
                    Button("Back") {
                        withAnimation { currentIndex -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(currentIndex == questions.count - 1 ? "Next" : "Continue") {
                    if currentIndex < questions.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        saveAssessment()
                        showGoalDeclaration = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvance)
            }
            .padding()
        }
        .navigationTitle("About You")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showGoalDeclaration) {
            GoalDeclarationView()
        }
    }

    private func binding(for questionId: String) -> Binding<Set<String>> {
        Binding(
            get: { answers[questionId] ?? [] },
            set: { answers[questionId] = $0 }
        )
    }

    private func saveAssessment() {
        guard let profile else { return }
        let assessment = CoreAssessment()
        assessment.cognitiveStyle = answers["focus_style"]?.first ?? ""
        assessment.peakEnergyTime = answers["peak_energy"]?.first ?? ""
        assessment.overwhelmResponse = answers["overwhelm_response"]?.first ?? ""

        let adhdFocus = adhdScore(answers["adhd_focus"]?.first)
        let adhdRestless = adhdScore(answers["adhd_restless"]?.first)
        assessment.adhdScore = adhdFocus + adhdRestless

        assessment.anxietyScore = anxietyScore(answers["anxiety_level"]?.first)
        assessment.sleepQualitySelfRating = sleepScore(answers["sleep_quality"]?.first)
        assessment.topValues = Array(answers["top_values"] ?? [])
        assessment.biggestBlocker = answers["biggest_blocker"]?.first ?? ""
        assessment.accountabilityPreference = answers["accountability"]?.first ?? ""

        profile.coreAssessment = assessment
    }

    private func adhdScore(_ value: String?) -> Int {
        switch value {
        case "never": 0
        case "rarely": 1
        case "sometimes": 2
        case "often": 3
        case "very_often": 4
        default: 0
        }
    }

    private func anxietyScore(_ value: String?) -> Int {
        switch value {
        case "not_at_all": 0
        case "several_days": 1
        case "more_than_half": 2
        case "nearly_every_day": 3
        default: 0
        }
    }

    private func sleepScore(_ value: String?) -> Int {
        switch value {
        case "great": 4
        case "ok": 3
        case "poor": 2
        case "terrible": 1
        default: 0
        }
    }
}
```

- [ ] **Step 4: Build GoalDeclarationView**

```swift
// ambidash/Views/Onboarding/GoalDeclarationView.swift
import SwiftUI
import SwiftData

struct GoalDeclarationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedDomains: Set<GoalDomain> = []
    @State private var showWorkStyle = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you want to work on?")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Pick as many as you want. You can always add or remove later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 10) {
                        ForEach(GoalDomain.allCases) { domain in
                            let isSelected = selectedDomains.contains(domain)

                            Button {
                                if isSelected {
                                    selectedDomains.remove(domain)
                                } else {
                                    selectedDomains.insert(domain)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: domain.icon)
                                        .font(.title3)
                                        .frame(width: 32)

                                    Text(domain.displayName)
                                        .font(.body)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(14)
                                .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Button {
                saveGoals()
                showWorkStyle = true
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDomains.isEmpty)
            .padding()
        }
        .navigationTitle("Your Goals")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showWorkStyle) {
            WorkStylePickerView()
        }
    }

    private func saveGoals() {
        guard let profile else { return }
        for (index, domain) in selectedDomains.sorted(by: { $0.displayName < $1.displayName }).enumerated() {
            let goal = Goal(title: domain.displayName, domain: domain, priority: index + 1)
            goal.streak = Streak()
            profile.goals.append(goal)
        }
    }
}
```

- [ ] **Step 5: Build WorkStylePickerView**

```swift
// ambidash/Views/Onboarding/WorkStylePickerView.swift
import SwiftUI
import SwiftData

struct WorkStylePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedFormat: PlanFormat?
    @State private var showComplete = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How should your daily plan look?")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("You can change this anytime in settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        ForEach(PlanFormat.allCases) { format in
                            let isSelected = selectedFormat == format

                            Button {
                                selectedFormat = format
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(format.displayName)
                                        .font(.headline)

                                    Text(format.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Button {
                savePreference()
                showComplete = true
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFormat == nil)
            .padding()
        }
        .navigationTitle("Work Style")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
    }

    private func savePreference() {
        guard let profile, let format = selectedFormat else { return }
        let pref = WorkStylePreference(planFormat: format)
        profile.workStylePreference = pref
    }
}
```

- [ ] **Step 6: Build OnboardingCompleteView**

```swift
// ambidash/Views/Onboarding/OnboardingCompleteView.swift
import SwiftUI
import SwiftData

struct OnboardingCompleteView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var goalCount: Int { profile?.goals.count ?? 0 }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("You're all set")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Profile built with \(goalCount) goals. Your dashboard is ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                profile?.onboardingComplete = true
            } label: {
                Text("Open Dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .navigationBarBackButtonHidden()
    }
}
```

- [ ] **Step 7: Build and run full onboarding flow**

Run: `Cmd+R`
Expected: Welcome → 10 assessment questions (one at a time with progress bar) → Goal selection → Work style picker → Complete → Transitions to main tab view

- [ ] **Step 8: Commit**

```bash
git add ambidash/Views/Onboarding/
git commit -m "feat: complete onboarding flow (assessment, goals, work style)"
```

---

### Task 7: Services — Score Calculators

**Files:**
- Create: `ambidash/Services/PulseScoreCalculator.swift`
- Create: `ambidash/Services/DimensionScoreCalculator.swift`
- Create: `ambidash/Services/GoalHealthService.swift`
- Test: `ambidashTests/Services/PulseScoreCalculatorTests.swift`
- Test: `ambidashTests/Services/DimensionScoreCalculatorTests.swift`
- Test: `ambidashTests/Services/GoalHealthServiceTests.swift`

- [ ] **Step 1: Write tests for GoalHealthService**

```swift
// ambidashTests/Services/GoalHealthServiceTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func goalHealthReturnsOnTrackForRecentProgress() {
    let goal = Goal(title: "Test", domain: .fitness, priority: 1)
    goal.lastProgressDate = .now
    let status = GoalHealthService.status(for: goal)
    #expect(status == .onTrack)
}

@Test func goalHealthReturnsSlippingForNeglectedGoal() {
    let goal = Goal(title: "Test", domain: .fitness, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
    let status = GoalHealthService.status(for: goal)
    #expect(status == .slipping)
}

@Test func goalHealthReturnsPausedForInactiveGoal() {
    let goal = Goal(title: "Test", domain: .fitness, priority: 1)
    goal.isActive = false
    let status = GoalHealthService.status(for: goal)
    #expect(status == .paused)
}

@Test func goalHealthSummaryTextForSlipping() {
    let goal = Goal(title: "Lean Body", domain: .fitness, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
    let summary = GoalHealthService.summaryText(for: goal)
    #expect(summary.contains("8 days"))
}
```

- [ ] **Step 2: Run tests — verify failure**

Expected: FAIL — `GoalHealthService` not defined

- [ ] **Step 3: Implement GoalHealthService**

```swift
// ambidash/Services/GoalHealthService.swift
import Foundation

enum GoalHealthService {
    static func status(for goal: Goal) -> GoalStatus {
        goal.computedStatus
    }

    static func summaryText(for goal: Goal) -> String {
        let days = goal.neglectDays
        switch goal.computedStatus {
        case .onTrack:
            if days == 0 {
                return "Active today"
            }
            return "Last active \(days) day\(days == 1 ? "" : "s") ago"
        case .needsAttention:
            return "No progress in \(days) days"
        case .slipping:
            return "Neglected for \(days) days"
        case .paused:
            return "Paused"
        }
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

Expected: All GoalHealthService tests pass

- [ ] **Step 5: Write tests for DimensionScoreCalculator**

```swift
// ambidashTests/Services/DimensionScoreCalculatorTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func dimensionScoreFromGoals() {
    let goals = [
        makeGoal(domain: .fitness, neglectDays: 0),
        makeGoal(domain: .cognitive, neglectDays: 5),
        makeGoal(domain: .social, neglectDays: 12),
    ]
    let scores = DimensionScoreCalculator.scores(from: goals, snapshot: nil)

    #expect(scores[.body]! > scores[.social]!)
    #expect(scores[.body]! >= 70)
    #expect(scores[.social]! <= 40)
}

@Test func dimensionScoreDefaults50WhenNoDimGoals() {
    let goals: [Goal] = []
    let scores = DimensionScoreCalculator.scores(from: goals, snapshot: nil)
    for dim in LifeDimension.allCases {
        #expect(scores[dim] == 50)
    }
}

private func makeGoal(domain: GoalDomain, neglectDays: Int) -> Goal {
    let goal = Goal(title: domain.displayName, domain: domain, priority: 1)
    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -neglectDays, to: .now)!
    return goal
}
```

- [ ] **Step 6: Implement DimensionScoreCalculator**

```swift
// ambidash/Services/DimensionScoreCalculator.swift
import Foundation

enum DimensionScoreCalculator {
    static func scores(from goals: [Goal], snapshot: IntegrationSnapshot?) -> [LifeDimension: Int] {
        var result: [LifeDimension: Int] = [:]

        for dim in LifeDimension.allCases {
            let dimGoals = goals.filter { $0.domain.dimension == dim && $0.isActive }
            if dimGoals.isEmpty {
                result[dim] = 50
                continue
            }

            let avg = dimGoals.map { goalScore($0) }.reduce(0, +) / dimGoals.count
            result[dim] = avg
        }

        if let snapshot {
            if snapshot.sleepHours > 0 {
                let sleepBonus = min(Int(snapshot.sleepHours / 8.0 * 100), 100)
                result[.body] = ((result[.body] ?? 50) + sleepBonus) / 2
            }
            if snapshot.screenTimeHours > 0 {
                let screenPenalty = max(100 - Int(snapshot.screenTimeHours * 15), 0)
                result[.focus] = ((result[.focus] ?? 50) + screenPenalty) / 2
            }
        }

        return result
    }

    private static func goalScore(_ goal: Goal) -> Int {
        let days = goal.neglectDays
        if days <= 1 { return 90 }
        if days <= 3 { return 75 }
        if days <= 5 { return 55 }
        if days <= 7 { return 40 }
        return max(10, 30 - (days - 7) * 3)
    }
}
```

- [ ] **Step 7: Write tests for PulseScoreCalculator**

```swift
// ambidashTests/Services/PulseScoreCalculatorTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func pulseScoreIsAverageOfDimensions() {
    let dimScores: [LifeDimension: Int] = [
        .body: 80, .mind: 60, .focus: 70, .social: 40, .growth: 50,
    ]
    let pulse = PulseScoreCalculator.pulse(from: dimScores)
    #expect(pulse == 60)
}

@Test func pulseScoreClampedTo0_100() {
    let low: [LifeDimension: Int] = [
        .body: 0, .mind: 0, .focus: 0, .social: 0, .growth: 0,
    ]
    #expect(PulseScoreCalculator.pulse(from: low) == 0)

    let high: [LifeDimension: Int] = [
        .body: 100, .mind: 100, .focus: 100, .social: 100, .growth: 100,
    ]
    #expect(PulseScoreCalculator.pulse(from: high) == 100)
}
```

- [ ] **Step 8: Implement PulseScoreCalculator**

```swift
// ambidash/Services/PulseScoreCalculator.swift
import Foundation

enum PulseScoreCalculator {
    static func pulse(from dimensionScores: [LifeDimension: Int]) -> Int {
        guard !dimensionScores.isEmpty else { return 50 }
        let total = dimensionScores.values.reduce(0, +)
        let avg = total / dimensionScores.count
        return min(max(avg, 0), 100)
    }
}
```

- [ ] **Step 9: Run all tests**

Expected: All pass

- [ ] **Step 10: Commit**

```bash
git add ambidash/Services/ ambidashTests/Services/
git commit -m "feat: add score calculators (pulse, dimensions, goal health)"
```

---

### Task 8: Dashboard View

**Files:**
- Modify: `ambidash/Views/Dashboard/DashboardView.swift`
- Create: `ambidash/Views/Dashboard/PulseScoreView.swift`
- Create: `ambidash/Views/Dashboard/DimensionBarsView.swift`
- Create: `ambidash/Views/Dashboard/QuickStatsView.swift`
- Create: `ambidash/Views/Dashboard/GoalStripView.swift`
- Create: `ambidash/Views/Dashboard/InsightCardView.swift`

- [ ] **Step 1: Build PulseScoreView**

```swift
// ambidash/Views/Dashboard/PulseScoreView.swift
import SwiftUI

struct PulseScoreView: View {
    let score: Int
    let trend: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("PULSE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }

            if trend != 0 {
                Text("\(trend > 0 ? "▲" : "▼") \(abs(trend)) from yesterday")
                    .font(.caption)
                    .foregroundStyle(trend > 0 ? .green : .red)
            }
        }
    }

    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 45 { return .orange }
        return .red
    }
}
```

- [ ] **Step 2: Build DimensionBarsView**

```swift
// ambidash/Views/Dashboard/DimensionBarsView.swift
import SwiftUI

struct DimensionBarsView: View {
    let scores: [LifeDimension: Int]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(LifeDimension.allCases, id: \.self) { dim in
                let score = scores[dim] ?? 50
                HStack {
                    Text(dim.displayName)
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(score))
                                .frame(width: geo.size.width * CGFloat(score) / 100)
                        }
                    }
                    .frame(height: 8)

                    Text("\(score)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private func barColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 45 { return .orange }
        return .red
    }
}
```

- [ ] **Step 3: Build QuickStatsView**

```swift
// ambidash/Views/Dashboard/QuickStatsView.swift
import SwiftUI

struct QuickStatsView: View {
    let snapshot: IntegrationSnapshot?

    var body: some View {
        HStack(spacing: 12) {
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.sleepHours) } ?? "—",
                label: "Sleep",
                color: .purple
            )
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.screenTimeHours) } ?? "—",
                label: "Screen",
                color: .red
            )
            StatBox(
                value: snapshot.map { "\(String(format: "%.1f", Double($0.steps) / 1000))k" } ?? "—",
                label: "Steps",
                color: .green
            )
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 4: Build GoalStripView**

```swift
// ambidash/Views/Dashboard/GoalStripView.swift
import SwiftUI

struct GoalStripView: View {
    let goals: [Goal]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(goals) { goal in
                    GoalChip(goal: goal)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct GoalChip: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goal.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(GoalHealthService.summaryText(for: goal))
                .font(.caption2)
                .foregroundStyle(goal.computedStatus.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 5: Build InsightCardView (placeholder)**

```swift
// ambidash/Views/Dashboard/InsightCardView.swift
import SwiftUI

struct InsightCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PATTERN SPOTTED")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
                .tracking(0.5)

            Text("Connect Apple Health and Calendar to unlock AI-powered insights about your patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 6: Wire up DashboardView**

```swift
// ambidash/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }

    private var goals: [Goal] {
        profile?.goals.filter(\.isActive) ?? []
    }

    private var dimensionScores: [LifeDimension: Int] {
        DimensionScoreCalculator.scores(from: goals, snapshot: todaySnapshot)
    }

    private var pulseScore: Int {
        PulseScoreCalculator.pulse(from: dimensionScores)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Pulse
                    PulseScoreView(score: pulseScore, trend: 0)

                    // Dimensions
                    DimensionBarsView(scores: dimensionScores)
                        .padding(.horizontal)

                    // Quick Stats
                    QuickStatsView(snapshot: todaySnapshot)
                        .padding(.horizontal)

                    // Goal Strip
                    if !goals.isEmpty {
                        GoalStripView(goals: goals)
                    }

                    // Insight
                    InsightCardView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profile?.name.isEmpty == false ? profile!.name : "there"
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 17 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }
}
```

- [ ] **Step 7: Build and run — verify dashboard**

Run: `Cmd+R`
Expected: After completing onboarding, the dashboard shows the pulse score ring, dimension bars (scored from your goals), empty quick stats (no integration data yet), goal strip with your selected goals showing "Active today", and the placeholder insight card.

- [ ] **Step 8: Commit**

```bash
git add ambidash/Views/Dashboard/
git commit -m "feat: build self-awareness dashboard (pulse, dimensions, stats, goal strip)"
```

---

### Task 9: Goal Management Views

**Files:**
- Modify: `ambidash/Views/Goals/GoalListView.swift`
- Create: `ambidash/Views/Goals/GoalDetailView.swift`
- Create: `ambidash/Views/Goals/AddGoalView.swift`

- [ ] **Step 1: Build GoalListView**

```swift
// ambidash/Views/Goals/GoalListView.swift
import SwiftUI
import SwiftData

struct GoalListView: View {
    @Query private var profiles: [UserProfile]
    @State private var showAddGoal = false

    private var goals: [Goal] {
        (profile?.goals ?? []).sorted { $0.priority < $1.priority }
    }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                let active = goals.filter(\.isActive)
                let paused = goals.filter { !$0.isActive }

                if !active.isEmpty {
                    Section("Active") {
                        ForEach(active) { goal in
                            NavigationLink(value: goal.id) {
                                GoalRow(goal: goal)
                            }
                        }
                    }
                }

                if !paused.isEmpty {
                    Section("Paused") {
                        ForEach(paused) { goal in
                            NavigationLink(value: goal.id) {
                                GoalRow(goal: goal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationDestination(for: UUID.self) { goalId in
                if let goal = goals.first(where: { $0.id == goalId }) {
                    GoalDetailView(goal: goal)
                }
            }
            .toolbar {
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
            }
            .overlay {
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals Yet",
                        systemImage: "target",
                        description: Text("Tap + to add your first goal")
                    )
                }
            }
        }
    }
}

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.domain.icon)
                .foregroundStyle(goal.computedStatus.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.body)
                Text(GoalHealthService.summaryText(for: goal))
                    .font(.caption)
                    .foregroundStyle(goal.computedStatus.color)
            }

            Spacer()

            if let streak = goal.streak, streak.currentCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(streak.currentCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build GoalDetailView**

```swift
// ambidash/Views/Goals/GoalDetailView.swift
import SwiftUI

struct GoalDetailView: View {
    @Bindable var goal: Goal

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: goal.domain.icon)
                        .font(.title)
                        .foregroundStyle(goal.computedStatus.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(goal.domain.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Status") {
                LabeledContent("Health", value: goal.computedStatus.label)
                LabeledContent("Days since progress", value: "\(goal.neglectDays)")
                LabeledContent("Priority", value: "\(goal.priority)")
                LabeledContent("Created", value: goal.createdAt.formatted(.dateTime.month().day().year()))

                if let streak = goal.streak {
                    LabeledContent("Current streak", value: "\(streak.currentCount) days")
                    LabeledContent("Best streak", value: "\(streak.bestCount) days")
                }
            }

            Section {
                Button(goal.isActive ? "Pause Goal" : "Resume Goal") {
                    goal.isActive.toggle()
                }

                Button("Log Progress") {
                    goal.lastProgressDate = .now
                    goal.streak?.recordActivity()
                }
                .tint(.green)
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Build AddGoalView**

```swift
// ambidash/Views/Goals/AddGoalView.swift
import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var title = ""
    @State private var selectedDomain: GoalDomain = .fitness

    private var profile: UserProfile? { profiles.first }

    private var existingDomains: Set<GoalDomain> {
        Set(profile?.goals.map(\.domain) ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("What do you want to achieve?", text: $title)

                    Picker("Domain", selection: $selectedDomain) {
                        ForEach(GoalDomain.allCases) { domain in
                            Label(domain.displayName, systemImage: domain.icon)
                                .tag(domain)
                        }
                    }
                }

                Section {
                    Text("Mapped to: \(selectedDomain.dimension.displayName) dimension")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGoal()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addGoal() {
        guard let profile else { return }
        let priority = (profile.goals.count) + 1
        let goal = Goal(title: title, domain: selectedDomain, priority: priority)
        goal.streak = Streak()
        profile.goals.append(goal)
    }
}
```

- [ ] **Step 4: Build and run — test goal management**

Run: `Cmd+R`
Expected: Goals tab shows all goals from onboarding. Can tap a goal to see detail. Can add new goals via +. Can log progress and pause/resume goals.

- [ ] **Step 5: Commit**

```bash
git add ambidash/Views/Goals/
git commit -m "feat: goal management views (list, detail, add goal)"
```

---

### Task 10: Add Name Collection to Onboarding

**Files:**
- Modify: `ambidash/Views/Onboarding/WelcomeView.swift`

The current WelcomeView doesn't collect the user's name, which the dashboard greeting needs.

- [ ] **Step 1: Add name and age input to WelcomeView**

```swift
// ambidash/Views/Onboarding/WelcomeView.swift
import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var age = ""
    @State private var showAssessment = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(age) != nil && Int(age)! >= 13
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("ambidash")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Your life, one dashboard.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("What's your name?", text: $name)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)

                    TextField("Age", text: $age)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, 48)

                    Text("~5 minutes to set up")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    let profile = UserProfile(
                        name: name.trimmingCharacters(in: .whitespaces),
                        age: Int(age) ?? 0
                    )
                    modelContext.insert(profile)
                    showAssessment = true
                } label: {
                    Text("Let's go")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $showAssessment) {
                AssessmentFlowView()
            }
        }
    }
}
```

- [ ] **Step 2: Build and run — verify name and age collected**

Run: `Cmd+R`
Expected: Welcome screen has name and age fields. After onboarding, dashboard says "Good morning, [name]"

- [ ] **Step 3: Commit**

```bash
git add ambidash/Views/Onboarding/WelcomeView.swift
git commit -m "feat: collect user name and age during onboarding"
```

---

### Task 11: Final Integration Test

- [ ] **Step 1: Run all unit tests**

Run: `Cmd+U` or `xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: All tests pass

- [ ] **Step 2: Full end-to-end walkthrough in simulator**

1. Fresh install — shows WelcomeView
2. Enter name, tap "Let's go"
3. Answer all 10 assessment questions one by one (progress bar advances)
4. Select 3+ goals on the goal declaration screen
5. Choose a work style (Focus Blocks)
6. Tap "Open Dashboard"
7. Dashboard shows: greeting with name, pulse score, dimension bars colored by goal health, empty quick stats, goal strip, placeholder insight card
8. Switch to Goals tab — all selected goals listed
9. Tap a goal — detail view shows status, streak, log progress button
10. Log progress on a goal — status updates to "Active today"
11. Add a new goal via + — appears in list and on dashboard goal strip
12. Kill app, relaunch — data persists, goes straight to dashboard

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "feat: complete core MVP (onboarding, dashboard, goals)"
```

---

## What This Plan Delivers

A working iOS app that:
- Onboards users with a 10-question assessment (cognitive style, ADHD/anxiety screening, values)
- Lets users declare goals across 7 life domains
- Shows a self-awareness dashboard with pulse score, dimension bars, quick stats, and goal health
- Manages goals (add, view detail, log progress, pause/resume)
- Persists all data locally via SwiftData
- Routes between onboarding and main app based on profile state

## What Comes Next (Plan 2+)

- **Plan 2:** HealthKit, EventKit, Screen Time integrations → real data in dashboard
- **Plan 3:** Daily plan engine + reflection system
- **Plan 4:** Cloud backend + AI mentor (Claude API)
- **Plan 5:** Push notifications, streaks, guilt nudges, StoreKit 2
- **Plan 6:** Notion/Obsidian integration, diminishing scaffolding, polish
