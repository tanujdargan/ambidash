# Daily Plan + Reflection — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "Today" tab (daily action plan with Done/Skip/Later tracking) and the "Reflect" tab (evening reflection with mood, blockers, and day summary). Template-based plan generation — AI-powered plans come in Plan 4.

**Architecture:** A PlanGenerator service creates daily plans from goals + calendar data using templates (no AI). The Today tab renders plans in the user's preferred format (focus blocks, single action, or priority list). The Reflect tab shows a day summary with quick-tap mood/blocker selection. All data persists in existing SwiftData models (DailyPlan, PlannedAction, Reflection).

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, iOS 17+

---

## File Structure

```
ambidash/
├── ambidash/
│   ├── Services/
│   │   └── PlanGenerator.swift            — Template-based daily plan creation
│   ├── Views/
│   │   ├── Today/
│   │   │   ├── TodayView.swift            — Today tab container
│   │   │   ├── FocusBlocksView.swift      — Time-slotted plan format
│   │   │   ├── SingleActionView.swift     — One-at-a-time format
│   │   │   ├── PriorityListView.swift     — Ranked list format
│   │   │   └── ActionRow.swift            — Reusable action item component
│   │   └── Reflect/
│   │       ├── ReflectView.swift          — Reflect tab container
│   │       ├── DailySummaryView.swift     — Auto-populated day stats
│   │       └── ReflectionFormView.swift   — Mood + blocker + freeform input
├── ambidashTests/
│   └── Services/
│       └── PlanGeneratorTests.swift
```

---

### Task 1: PlanGenerator Service (TDD)

**Files:**
- Create: `ambidash/Services/PlanGenerator.swift`
- Create: `ambidashTests/Services/PlanGeneratorTests.swift`

- [ ] **Step 1: Write tests**

```swift
// ambidashTests/Services/PlanGeneratorTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func planGeneratorCreatesActionsForActiveGoals() {
    let goals = [
        Goal(title: "Lean Body", domain: .fitness, priority: 1),
        Goal(title: "SWE Skills", domain: .career, priority: 2),
        Goal(title: "Language", domain: .language, priority: 3),
    ]
    let actions = PlanGenerator.generateActions(for: goals, freeMinutes: 480, maxActions: 6)
    #expect(!actions.isEmpty)
    #expect(actions.count <= 6)
    #expect(actions.allSatisfy { !$0.title.isEmpty })
}

@Test func planGeneratorRespectsMaxActions() {
    let goals = (1...10).map { Goal(title: "Goal \($0)", domain: .fitness, priority: $0) }
    let actions = PlanGenerator.generateActions(for: goals, freeMinutes: 480, maxActions: 4)
    #expect(actions.count <= 4)
}

@Test func planGeneratorPrioritizesNeglectedGoals() {
    let fresh = Goal(title: "Fresh", domain: .fitness, priority: 1)
    fresh.lastProgressDate = .now

    let neglected = Goal(title: "Neglected", domain: .career, priority: 2)
    neglected.lastProgressDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!

    let actions = PlanGenerator.generateActions(for: [fresh, neglected], freeMinutes: 480, maxActions: 6)
    let neglectedActions = actions.filter { $0.goalTitle == "Neglected" }
    let freshActions = actions.filter { $0.goalTitle == "Fresh" }
    #expect(neglectedActions.count >= freshActions.count)
}

@Test func planGeneratorHandlesNoGoals() {
    let actions = PlanGenerator.generateActions(for: [], freeMinutes: 480, maxActions: 6)
    #expect(actions.isEmpty)
}
```

- [ ] **Step 2: Implement PlanGenerator**

```swift
// ambidash/Services/PlanGenerator.swift
import Foundation

enum PlanGenerator {
    struct ActionTemplate {
        let title: String
        let goalTitle: String
        let domain: GoalDomain
        let durationMinutes: Int
        let why: String
    }

    private static let templates: [GoalDomain: [(String, Int, String)]] = [
        .fitness: [
            ("Workout session", 45, "Consistency builds the body you want"),
            ("30-minute walk", 30, "Active recovery and fresh air"),
            ("Stretching routine", 15, "Flexibility prevents injury"),
        ],
        .cognitive: [
            ("Deep reading session", 45, "Build knowledge that compounds"),
            ("Learn something new (video/article)", 30, "Expand your mental models"),
            ("Practice recall on recent learning", 20, "Retrieval strengthens memory"),
        ],
        .career: [
            ("Deep work on main project", 90, "Focused work moves the needle"),
            ("Code review or skill practice", 45, "Sharpen the saw"),
            ("Research/planning session", 30, "Strategy before execution"),
        ],
        .language: [
            ("Language practice", 20, "Daily practice builds fluency"),
            ("Listen to content in target language", 15, "Immersion accelerates learning"),
        ],
        .social: [
            ("Reach out to one person", 10, "Relationships need maintenance"),
            ("Social challenge: start a conversation", 15, "Growth happens outside comfort zones"),
        ],
        .screenTime: [
            ("Phone-free block", 60, "Reclaim your attention"),
            ("Delete or mute one notification source", 5, "Reduce digital noise"),
        ],
        .financial: [
            ("Review budget or spending", 20, "Awareness drives better decisions"),
            ("Work on income-generating project", 60, "Build assets, not just habits"),
        ],
    ]

    static func generateActions(for goals: [Goal], freeMinutes: Int, maxActions: Int) -> [ActionTemplate] {
        let active = goals.filter(\.isActive)
        guard !active.isEmpty else { return [] }

        let sorted = active.sorted { a, b in
            if a.neglectDays != b.neglectDays { return a.neglectDays > b.neglectDays }
            return a.priority < b.priority
        }

        var result: [ActionTemplate] = []
        var remainingMinutes = freeMinutes
        var usedGoals: Set<String> = []

        for goal in sorted {
            if result.count >= maxActions { break }
            if remainingMinutes <= 0 { break }

            let domainTemplates = templates[goal.domain] ?? []
            guard let template = domainTemplates.first(where: { t in
                t.1 <= remainingMinutes && !usedGoals.contains("\(goal.title)-\(t.0)")
            }) else { continue }

            result.append(ActionTemplate(
                title: template.0,
                goalTitle: goal.title,
                domain: goal.domain,
                durationMinutes: template.1,
                why: template.2
            ))
            remainingMinutes -= template.1
            usedGoals.insert("\(goal.title)-\(template.0)")
        }

        if result.count < maxActions && result.count < active.count {
            for goal in sorted where result.count < maxActions && remainingMinutes > 0 {
                let domainTemplates = templates[goal.domain] ?? []
                for template in domainTemplates {
                    let key = "\(goal.title)-\(template.0)"
                    if !usedGoals.contains(key) && template.1 <= remainingMinutes {
                        result.append(ActionTemplate(
                            title: template.0,
                            goalTitle: goal.title,
                            domain: goal.domain,
                            durationMinutes: template.1,
                            why: template.2
                        ))
                        remainingMinutes -= template.1
                        usedGoals.insert(key)
                        break
                    }
                }
            }
        }

        return result
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodegen generate && xcrun simctl shutdown all 2>/dev/null; xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(✔|✘|Test run with)"`
Expected: All pass (19 existing + 4 new = 23)

- [ ] **Step 4: Commit**

```bash
git add ambidash/Services/PlanGenerator.swift ambidashTests/Services/PlanGeneratorTests.swift
git commit -m "feat: add template-based PlanGenerator with goal prioritization"
```

---

### Task 2: ActionRow Component + Today View

**Files:**
- Create: `ambidash/Views/Today/ActionRow.swift`
- Create: `ambidash/Views/Today/FocusBlocksView.swift`
- Create: `ambidash/Views/Today/SingleActionView.swift`
- Create: `ambidash/Views/Today/PriorityListView.swift`
- Create: `ambidash/Views/Today/TodayView.swift`

- [ ] **Step 1: Create ActionRow**

```swift
// ambidash/Views/Today/ActionRow.swift
import SwiftUI

struct ActionRow: View {
    @Bindable var action: PlannedAction
    var onDone: () -> Void
    var onSkip: () -> Void

    private var isDone: Bool { action.statusRaw == "done" }
    private var isSkipped: Bool { action.statusRaw == "skipped" }
    private var isCompleted: Bool { isDone || isSkipped }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)

                    if !action.whyReasoning.isEmpty {
                        Text(action.whyReasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Spacer()

                Text("\(action.durationMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !isCompleted {
                HStack(spacing: 8) {
                    Button("Done") {
                        action.statusRaw = "done"
                        action.completedAt = .now
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Skip") {
                        action.statusRaw = "skipped"
                        onSkip()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text(isDone ? "Completed" : "Skipped")
                    .font(.caption)
                    .foregroundStyle(isDone ? .green : .orange)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Create FocusBlocksView**

```swift
// ambidash/Views/Today/FocusBlocksView.swift
import SwiftUI

struct FocusBlocksView: View {
    let actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(actions) { action in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(colorForStatus(action.statusRaw))
                        .frame(width: 4)

                    ActionRow(action: action, onDone: { onDone(action) }, onSkip: { onSkip(action) })
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "done": .green
        case "skipped": .orange
        default: .blue
        }
    }
}
```

- [ ] **Step 3: Create SingleActionView**

```swift
// ambidash/Views/Today/SingleActionView.swift
import SwiftUI

struct SingleActionView: View {
    let actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    private var currentAction: PlannedAction? {
        actions.first { $0.statusRaw == "pending" }
    }

    private var completedCount: Int {
        actions.filter { $0.statusRaw != "pending" }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            if let action = currentAction {
                Text("Action \(completedCount + 1) of \(actions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Text(action.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("\(action.durationMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !action.whyReasoning.isEmpty {
                        Text(action.whyReasoning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button {
                        action.statusRaw = "done"
                        action.completedAt = .now
                        onDone(action)
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        action.statusRaw = "skipped"
                        onSkip(action)
                    } label: {
                        Text("Skip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("All done for today")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(actions.filter { $0.statusRaw == "done" }.count) completed, \(actions.filter { $0.statusRaw == "skipped" }.count) skipped")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
            }
        }
    }
}
```

- [ ] **Step 4: Create PriorityListView**

```swift
// ambidash/Views/Today/PriorityListView.swift
import SwiftUI

struct PriorityListView: View {
    let actions: [PlannedAction]
    var onDone: (PlannedAction) -> Void
    var onSkip: (PlannedAction) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    ActionRow(action: action, onDone: { onDone(action) }, onSkip: { onSkip(action) })
                }
            }
        }
    }
}
```

- [ ] **Step 5: Create TodayView**

```swift
// ambidash/Views/Today/TodayView.swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    private var profile: UserProfile? { profiles.first }

    private var todayPlan: DailyPlan? {
        let today = Calendar.current.startOfDay(for: .now)
        return plans.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var planFormat: PlanFormat {
        profile?.workStylePreference.flatMap { PlanFormat(rawValue: $0.planFormat) } ?? .focusBlocks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let plan = todayPlan {
                        let sortedActions = plan.actions.sorted { a, b in
                            if a.statusRaw == "pending" && b.statusRaw != "pending" { return true }
                            if a.statusRaw != "pending" && b.statusRaw == "pending" { return false }
                            return a.timeSlot < b.timeSlot
                        }

                        header(actionCount: plan.actions.count, doneCount: plan.actions.filter { $0.statusRaw == "done" }.count)

                        switch planFormat {
                        case .focusBlocks:
                            FocusBlocksView(actions: sortedActions, onDone: handleDone, onSkip: handleSkip)
                        case .singleAction:
                            SingleActionView(actions: sortedActions, onDone: handleDone, onSkip: handleSkip)
                        case .priorityList:
                            PriorityListView(actions: sortedActions, onDone: handleDone, onSkip: handleSkip)
                        }
                    } else {
                        generatePlanButton
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func header(actionCount: Int, doneCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(doneCount) of \(actionCount) completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var generatePlanButton: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("No plan for today yet")
                .font(.title3)
                .fontWeight(.semibold)

            Button {
                generatePlan()
            } label: {
                Text("Generate Today's Plan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            Spacer(minLength: 100)
        }
    }

    private func generatePlan() {
        let goals = profile?.goals ?? []
        let freeMinutes = 480
        let maxActions = profile?.workStylePreference.flatMap { $0.maxActionsPerDay } ?? 6

        let templates = PlanGenerator.generateActions(for: goals, freeMinutes: freeMinutes, maxActions: maxActions)

        let plan = DailyPlan(date: .now, format: planFormat)
        plan.actionCount = templates.count

        let timeSlots = ["07:00", "08:30", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"]

        for (index, template) in templates.enumerated() {
            let action = PlannedAction(
                title: template.title,
                why: template.why,
                timeSlot: index < timeSlots.count ? timeSlots[index] : "",
                duration: template.durationMinutes
            )
            plan.actions.append(action)
        }

        modelContext.insert(plan)
        try? modelContext.save()
    }

    private func handleDone(_ action: PlannedAction) {
        if let goal = profile?.goals.first(where: { $0.title == findGoalTitle(for: action) }) {
            goal.lastProgressDate = .now
            goal.streak?.recordActivity()
        }
        try? modelContext.save()
    }

    private func handleSkip(_ action: PlannedAction) {
        try? modelContext.save()
    }

    private func findGoalTitle(for action: PlannedAction) -> String {
        let goals = profile?.goals ?? []
        for goal in goals {
            let domainTemplates = PlanGenerator.templates(for: goal.domain)
            if domainTemplates.contains(where: { $0.0 == action.title }) {
                return goal.title
            }
        }
        return ""
    }
}
```

**Note:** We need to expose `PlanGenerator.templates(for:)` as a public lookup. Add this to `PlanGenerator.swift`:

```swift
static func templates(for domain: GoalDomain) -> [(String, Int, String)] {
    templates[domain] ?? []
}
```

- [ ] **Step 6: Wire TodayView into MainTabView**

In `ambidash/App/MainTabView.swift`, replace the `Text("Today — Plan 3")` placeholder with `TodayView()`. Find both the iOS 18 and iOS 17 versions and replace both.

- [ ] **Step 7: Build, test, commit**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Commit:
```bash
git add ambidash/Views/Today/ ambidash/App/MainTabView.swift ambidash/Services/PlanGenerator.swift
git commit -m "feat: add Today tab with daily plan generation and Done/Skip tracking"
```

---

### Task 3: Reflection Views

**Files:**
- Create: `ambidash/Views/Reflect/DailySummaryView.swift`
- Create: `ambidash/Views/Reflect/ReflectionFormView.swift`
- Create: `ambidash/Views/Reflect/ReflectView.swift`

- [ ] **Step 1: Create DailySummaryView**

```swift
// ambidash/Views/Reflect/DailySummaryView.swift
import SwiftUI

struct DailySummaryView: View {
    let plan: DailyPlan?
    let snapshot: IntegrationSnapshot?

    private var doneCount: Int { plan?.actions.filter { $0.statusRaw == "done" }.count ?? 0 }
    private var skippedCount: Int { plan?.actions.filter { $0.statusRaw == "skipped" }.count ?? 0 }
    private var totalCount: Int { plan?.actions.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S RESULTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 6) {
                SummaryRow(label: "Actions completed", value: "\(doneCount) of \(totalCount)", color: doneCount == totalCount ? .green : .orange)
                SummaryRow(label: "Actions skipped", value: "\(skippedCount)", color: skippedCount > 0 ? .red : .green)

                if let snap = snapshot {
                    SummaryRow(label: "Sleep", value: String(format: "%.1fh", snap.sleepHours), color: snap.sleepHours >= 7 ? .green : .orange)
                    SummaryRow(label: "Screen time", value: String(format: "%.1fh", snap.screenTimeHours), color: snap.screenTimeHours <= 3 ? .green : .red)
                    SummaryRow(label: "Steps", value: "\(snap.steps)", color: snap.steps >= 8000 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
```

- [ ] **Step 2: Create ReflectionFormView**

```swift
// ambidash/Views/Reflect/ReflectionFormView.swift
import SwiftUI
import SwiftData

struct ReflectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood = ""
    @State private var selectedBlockers: Set<String> = []
    @State private var freeformText = ""
    @State private var saved = false

    let existingReflection: Reflection?

    private let moods = ["Crushed it", "Decent", "Meh", "Bad day"]
    private let blockers = ["Procrastination", "Low energy", "Unexpected events", "Anxiety", "Nothing"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mood
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you feel about today?")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    ForEach(moods, id: \.self) { mood in
                        let isSelected = selectedMood == mood
                        Button(mood) {
                            selectedMood = mood
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue.opacity(0.2) : Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1))
                    }
                }
            }

            // Blockers
            VStack(alignment: .leading, spacing: 8) {
                Text("What got in the way?")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                FlowLayout(spacing: 8) {
                    ForEach(blockers, id: \.self) { blocker in
                        let isSelected = selectedBlockers.contains(blocker)
                        Button(blocker) {
                            if isSelected { selectedBlockers.remove(blocker) }
                            else { selectedBlockers.insert(blocker) }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue.opacity(0.2) : Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1))
                    }
                }
            }

            // Freeform
            VStack(alignment: .leading, spacing: 8) {
                Text("Anything else? (optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("Free-form thoughts...", text: $freeformText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }

            // Save
            Button {
                saveReflection()
            } label: {
                Text(saved ? "Saved" : "Save Reflection")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedMood.isEmpty || saved)
        }
        .onAppear {
            if let r = existingReflection {
                selectedMood = r.mood
                selectedBlockers = Set(r.blockers)
                freeformText = r.freeformText
                saved = true
            }
        }
    }

    private func saveReflection() {
        if let existing = existingReflection {
            existing.mood = selectedMood
            existing.blockers = Array(selectedBlockers)
            existing.freeformText = freeformText
        } else {
            let reflection = Reflection()
            reflection.mood = selectedMood
            reflection.blockers = Array(selectedBlockers)
            reflection.freeformText = freeformText
            modelContext.insert(reflection)
        }
        try? modelContext.save()
        saved = true
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
```

- [ ] **Step 3: Create ReflectView**

```swift
// ambidash/Views/Reflect/ReflectView.swift
import SwiftUI
import SwiftData

struct ReflectView: View {
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayReflection: Reflection? {
        reflections.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todaySnapshot: IntegrationSnapshot? {
        snapshots.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Evening Reflection")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DailySummaryView(plan: todayPlan, snapshot: todaySnapshot)

                    ReflectionFormView(existingReflection: todayReflection)
                }
                .padding()
            }
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

- [ ] **Step 4: Wire ReflectView into MainTabView**

In `ambidash/App/MainTabView.swift`, replace both `Text("Reflect — Plan 3")` placeholders with `ReflectView()`.

- [ ] **Step 5: Build, test, commit**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Commit:
```bash
git add ambidash/Views/Reflect/ ambidash/App/MainTabView.swift
git commit -m "feat: add Reflect tab with day summary and reflection form"
```

---

## What This Plan Delivers

- **Today tab** with template-based daily plan generation
- **Three plan formats** (focus blocks, single action, priority list) adapting to user preference
- **Done/Skip tracking** that updates goal progress and streaks
- **Reflect tab** with auto-populated day summary and mood/blocker/freeform input
- **PlanGenerator** with TDD tests prioritizing neglected goals
- All four tabs now functional (Dashboard, Today, Goals, Reflect)
