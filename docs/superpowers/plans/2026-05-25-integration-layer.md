# Integration Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect ambidash to Apple Health and Calendar so the dashboard shows real data instead of placeholder dashes.

**Architecture:** Two service classes (HealthKitService, EventKitService) handle authorization and data fetching. A SnapshotBuilder normalizes raw data into the existing IntegrationSnapshot SwiftData model. An IntegrationManager coordinates everything on app launch. Dashboard already reads from IntegrationSnapshot — no view changes needed.

**Tech Stack:** HealthKit, EventKit, SwiftData, Swift Testing, iOS 17+

**This is Plan 2 of 6.** Builds on the Core MVP (Plan 1). Screen Time (DeviceActivity) is deferred to Plan 2B due to its separate app extension requirement.

---

## File Structure

```
ambidash/
├── ambidash/
│   ├── Services/
│   │   ├── HealthKitService.swift       — HealthKit authorization + queries (sleep, steps, workouts, HR)
│   │   ├── EventKitService.swift        — EventKit authorization + queries (events, free time, reminders)
│   │   ├── SnapshotBuilder.swift        — Normalizes raw data into IntegrationSnapshot
│   │   └── IntegrationManager.swift     — Coordinates services, triggers snapshot build on app open
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   └── IntegrationSetupView.swift — Permission request UI during onboarding
│   │   └── Dashboard/
│   │       └── QuickStatsView.swift     — (modify) Add trend arrows from snapshot history
├── ambidashTests/
│   └── Services/
│       └── SnapshotBuilderTests.swift   — Tests for data normalization logic
```

---

### Task 1: Project Configuration — HealthKit + EventKit Capabilities

**Files:**
- Modify: `project.yml`
- Modify: `ambidash/ambidash.entitlements`

- [ ] **Step 1: Add HealthKit and Calendar capabilities to project.yml**

```yaml
# In project.yml, under targets > ambidash > settings > base, add:
        INFOPLIST_KEY_NSHealthShareUsageDescription: "ambidash reads your health data (sleep, steps, workouts, heart rate) to power your self-awareness dashboard and personalize your daily plan."
        INFOPLIST_KEY_NSHealthUpdateUsageDescription: "ambidash does not write health data."
        INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription: "ambidash reads your calendar to find free time for your daily action plan and understand how you spend your time."
        INFOPLIST_KEY_NSRemindersFullAccessUsageDescription: "ambidash reads your reminders to understand what tasks are on your mind."
```

Also add HealthKit to entitlements. Update `ambidash/ambidash.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
	<key>com.apple.developer.icloud-container-identifiers</key>
	<array>
		<string>iCloud.com.ambidash.app</string>
	</array>
	<key>com.apple.developer.icloud-services</key>
	<array>
		<string>CloudKit</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Regenerate project and verify build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add project.yml ambidash/ambidash.entitlements
git commit -m "feat: add HealthKit and Calendar capabilities to project config"
```

---

### Task 2: HealthKitService — Authorization + Data Fetching

**Files:**
- Create: `ambidash/Services/HealthKitService.swift`

- [ ] **Step 1: Implement HealthKitService**

```swift
// ambidash/Services/HealthKitService.swift
import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let workout = HKObjectType.workoutType() as HKObjectType? { types.insert(workout) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        return types
    }()

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func fetchSleepHours(for date: Date) async -> Double {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, results, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKCategorySample] ?? [])
                    }
                }
                store.execute(query)
            }

            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            ]

            let totalSeconds = samples
                .filter { asleepValues.contains($0.value) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

            return totalSeconds / 3600.0
        } catch {
            return 0
        }
    }

    func fetchSteps(for date: Date) async -> Int {
        let stepsType = HKQuantityType(.stepCount)
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: stepsType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let sum = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                        continuation.resume(returning: sum)
                    }
                }
                store.execute(query)
            }
            return Int(result)
        } catch {
            return 0
        }
    }

    func fetchWorkoutCount(for date: Date) async -> Int {
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        do {
            let count = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
                let query = HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, results, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results?.count ?? 0)
                    }
                }
                store.execute(query)
            }
            return count
        } catch {
            return 0
        }
    }

    func fetchRestingHeartRate(for date: Date) async -> Double {
        let hrType = HKQuantityType(.heartRate)
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: hrType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, stats, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let avg = stats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                        continuation.resume(returning: avg)
                    }
                }
                store.execute(query)
            }
            return result
        } catch {
            return 0
        }
    }

    private func dayBounds(for date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ambidash/Services/HealthKitService.swift
git commit -m "feat: add HealthKitService with sleep, steps, workouts, heart rate queries"
```

---

### Task 3: EventKitService — Calendar + Reminders

**Files:**
- Create: `ambidash/Services/EventKitService.swift`

- [ ] **Step 1: Implement EventKitService**

```swift
// ambidash/Services/EventKitService.swift
import Foundation
import EventKit

@MainActor
final class EventKitService {
    static let shared = EventKitService()

    private let store = EKEventStore()

    func requestCalendarAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func fetchTodayEvents() async -> [EKEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    func computeFreeMinutes(for date: Date) async -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let wakeHour = 7
        let sleepHour = 23
        guard let blockStart = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: dayStart),
              let blockEnd = calendar.date(bySettingHour: sleepHour, minute: 0, second: 0, of: dayStart) else {
            return 0
        }

        let totalMinutes = (sleepHour - wakeHour) * 60

        let predicate = store.predicateForEvents(withStart: blockStart, end: blockEnd, calendars: nil)
        let events = store.events(matching: predicate)

        let busyMinutes = events
            .filter { !$0.isAllDay }
            .reduce(0) { total, event in
                let eventStart = max(event.startDate, blockStart)
                let eventEnd = min(event.endDate, blockEnd)
                let minutes = Int(eventEnd.timeIntervalSince(eventStart) / 60)
                return total + max(minutes, 0)
            }

        return max(totalMinutes - busyMinutes, 0)
    }

    func fetchOverdueReminderCount() async -> Int {
        do {
            let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
                let predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: .now,
                    calendars: nil
                )
                store.fetchReminders(matching: predicate) { reminders in
                    continuation.resume(returning: reminders ?? [])
                }
            }
            return reminders.count
        } catch {
            return 0
        }
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ambidash/Services/EventKitService.swift
git commit -m "feat: add EventKitService with calendar events, free time, reminders"
```

---

### Task 4: SnapshotBuilder — Normalization Logic

**Files:**
- Create: `ambidash/Services/SnapshotBuilder.swift`
- Create: `ambidashTests/Services/SnapshotBuilderTests.swift`

- [ ] **Step 1: Write tests for SnapshotBuilder**

```swift
// ambidashTests/Services/SnapshotBuilderTests.swift
import Testing
import Foundation
@testable import ambidash

@Test func snapshotBuilderCreatesSnapshotFromRawData() {
    let raw = SnapshotBuilder.RawData(
        sleepHours: 7.5,
        steps: 8432,
        workoutCount: 1,
        restingHeartRate: 62.0,
        calendarFreeMinutes: 420,
        overdueReminders: 3
    )
    let snapshot = SnapshotBuilder.build(from: raw, for: .now)

    #expect(snapshot.sleepHours == 7.5)
    #expect(snapshot.steps == 8432)
    #expect(snapshot.workoutCount == 1)
    #expect(snapshot.calendarFreeMinutes == 420)
}

@Test func snapshotBuilderComputesSleepScore() {
    let good = SnapshotBuilder.RawData(sleepHours: 8.0)
    let goodSnapshot = SnapshotBuilder.build(from: good, for: .now)
    #expect(goodSnapshot.sleepScore >= 80)

    let bad = SnapshotBuilder.RawData(sleepHours: 4.0)
    let badSnapshot = SnapshotBuilder.build(from: bad, for: .now)
    #expect(badSnapshot.sleepScore <= 40)
}

@Test func snapshotBuilderHandlesZeroData() {
    let empty = SnapshotBuilder.RawData()
    let snapshot = SnapshotBuilder.build(from: empty, for: .now)

    #expect(snapshot.sleepHours == 0)
    #expect(snapshot.steps == 0)
    #expect(snapshot.sleepScore == 0)
}

@Test func snapshotBuilderUpdatesExistingSnapshot() {
    let existing = IntegrationSnapshot(date: .now)
    existing.sleepHours = 5.0

    let raw = SnapshotBuilder.RawData(sleepHours: 7.5, steps: 5000)
    SnapshotBuilder.update(existing, with: raw)

    #expect(existing.sleepHours == 7.5)
    #expect(existing.steps == 5000)
}
```

- [ ] **Step 2: Run tests — verify failure**

Expected: FAIL — `SnapshotBuilder` not defined

- [ ] **Step 3: Implement SnapshotBuilder**

```swift
// ambidash/Services/SnapshotBuilder.swift
import Foundation

enum SnapshotBuilder {
    struct RawData {
        var sleepHours: Double = 0
        var steps: Int = 0
        var workoutCount: Int = 0
        var restingHeartRate: Double = 0
        var calendarFreeMinutes: Int = 0
        var overdueReminders: Int = 0
        var screenTimeHours: Double = 0
        var screenCategories: [String: Double] = [:]
        var pickups: Int = 0
    }

    static func build(from raw: RawData, for date: Date) -> IntegrationSnapshot {
        let snapshot = IntegrationSnapshot(date: date)
        apply(raw, to: snapshot)
        return snapshot
    }

    static func update(_ snapshot: IntegrationSnapshot, with raw: RawData) {
        apply(raw, to: snapshot)
    }

    private static func apply(_ raw: RawData, to snapshot: IntegrationSnapshot) {
        snapshot.sleepHours = raw.sleepHours
        snapshot.sleepScore = computeSleepScore(hours: raw.sleepHours)
        snapshot.steps = raw.steps
        snapshot.workoutCount = raw.workoutCount
        snapshot.calendarFreeMinutes = raw.calendarFreeMinutes
        snapshot.screenTimeHours = raw.screenTimeHours
        snapshot.screenCategories = raw.screenCategories
        snapshot.pickups = raw.pickups
    }

    private static func computeSleepScore(hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours >= 9 { return 85 }
        if hours >= 7 { return Int(80 + (hours - 7) * 5) }
        if hours >= 6 { return Int(50 + (hours - 6) * 30) }
        return max(Int(hours / 6 * 50), 5)
    }
}
```

- [ ] **Step 4: Regenerate and run tests**

Run: `xcodegen generate && xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(✔|✘|Test run with|error:.*Build)"`
Expected: All tests pass (15 existing + 4 new = 19)

- [ ] **Step 5: Commit**

```bash
git add ambidash/Services/SnapshotBuilder.swift ambidashTests/Services/SnapshotBuilderTests.swift
git commit -m "feat: add SnapshotBuilder with normalization logic and sleep scoring"
```

---

### Task 5: IntegrationManager — Coordination Layer

**Files:**
- Create: `ambidash/Services/IntegrationManager.swift`

- [ ] **Step 1: Implement IntegrationManager**

```swift
// ambidash/Services/IntegrationManager.swift
import Foundation
import SwiftData

@MainActor
@Observable
final class IntegrationManager {
    private let healthKit = HealthKitService.shared
    private let eventKit = EventKitService.shared

    var healthAuthorized = false
    var calendarAuthorized = false
    var remindersAuthorized = false
    var isLoading = false

    func requestAllPermissions() async {
        async let health = healthKit.requestAuthorization()
        async let calendar = eventKit.requestCalendarAccess()
        async let reminders = eventKit.requestRemindersAccess()

        healthAuthorized = await health
        calendarAuthorized = await calendar
        remindersAuthorized = await reminders
    }

    func refreshTodaySnapshot(in context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        let today = Date.now

        var raw = SnapshotBuilder.RawData()

        if healthAuthorized {
            async let sleep = healthKit.fetchSleepHours(for: today)
            async let steps = healthKit.fetchSteps(for: today)
            async let workouts = healthKit.fetchWorkoutCount(for: today)
            async let hr = healthKit.fetchRestingHeartRate(for: today)

            raw.sleepHours = await sleep
            raw.steps = await steps
            raw.workoutCount = await workouts
            raw.restingHeartRate = await hr
        }

        if calendarAuthorized {
            raw.calendarFreeMinutes = await eventKit.computeFreeMinutes(for: today)
        }

        if remindersAuthorized {
            raw.overdueReminders = await eventKit.fetchOverdueReminderCount()
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)

        let descriptor = FetchDescriptor<IntegrationSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.date >= startOfDay
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            SnapshotBuilder.update(existing, with: raw)
        } else {
            let snapshot = SnapshotBuilder.build(from: raw, for: today)
            context.insert(snapshot)
        }

        try? context.save()
    }
}
```

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ambidash/Services/IntegrationManager.swift
git commit -m "feat: add IntegrationManager coordinating HealthKit + EventKit data refresh"
```

---

### Task 6: Integration Setup View + Onboarding Wiring

**Files:**
- Create: `ambidash/Views/Onboarding/IntegrationSetupView.swift`
- Modify: `ambidash/Views/Onboarding/OnboardingCompleteView.swift`

- [ ] **Step 1: Create IntegrationSetupView**

```swift
// ambidash/Views/Onboarding/IntegrationSetupView.swift
import SwiftUI

struct IntegrationSetupView: View {
    @State private var manager = IntegrationManager()
    @State private var showComplete = false
    @State private var requested = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect your data")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ambidash works best when it can see your health and calendar data. You can change this anytime in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        IntegrationRow(
                            icon: "heart.fill",
                            title: "Apple Health",
                            subtitle: "Sleep, steps, workouts, heart rate",
                            connected: manager.healthAuthorized
                        )
                        IntegrationRow(
                            icon: "calendar",
                            title: "Calendar",
                            subtitle: "Events, free time for planning",
                            connected: manager.calendarAuthorized
                        )
                        IntegrationRow(
                            icon: "checklist",
                            title: "Reminders",
                            subtitle: "Overdue tasks, completion patterns",
                            connected: manager.remindersAuthorized
                        )
                    }
                    .padding(.horizontal)

                    if !requested {
                        Text("Tapping 'Connect' will show permission dialogs from iOS. We only read data — we never write or modify anything.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }
            }

            VStack(spacing: 10) {
                if !requested {
                    Button {
                        Task {
                            await manager.requestAllPermissions()
                            requested = true
                        }
                    } label: {
                        Text("Connect")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    showComplete = true
                } label: {
                    Text(requested ? "Continue" : "Skip for now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(requested ? .borderedProminent : .bordered)
            }
            .padding()
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
    }
}

private struct IntegrationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(connected ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Update WorkStylePickerView to navigate to IntegrationSetupView instead of OnboardingCompleteView**

In `ambidash/Views/Onboarding/WorkStylePickerView.swift`, change the navigation destination from `OnboardingCompleteView()` to `IntegrationSetupView()`:

Find:
```swift
        .navigationDestination(isPresented: $showComplete) {
            OnboardingCompleteView()
        }
```

Replace with:
```swift
        .navigationDestination(isPresented: $showComplete) {
            IntegrationSetupView()
        }
```

- [ ] **Step 3: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ambidash/Views/Onboarding/ ambidash/Views/Onboarding/IntegrationSetupView.swift
git commit -m "feat: add integration setup screen to onboarding flow"
```

---

### Task 7: Dashboard Wiring — Auto-Refresh on App Open

**Files:**
- Modify: `ambidash/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: Add IntegrationManager to DashboardView and trigger refresh**

Replace the entire DashboardView with:

```swift
// ambidash/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    @State private var manager = IntegrationManager()

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

                    PulseScoreView(score: pulseScore, trend: 0)

                    DimensionBarsView(scores: dimensionScores)
                        .padding(.horizontal)

                    QuickStatsView(snapshot: todaySnapshot)
                        .padding(.horizontal)

                    if !goals.isEmpty {
                        GoalStripView(goals: goals)
                    }

                    InsightCardView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .refreshable {
                await manager.refreshTodaySnapshot(in: modelContext)
            }
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

Key changes from the existing version:
- Added `@Environment(\.modelContext)` to pass to IntegrationManager
- Added `@State private var manager = IntegrationManager()`
- Added `.task` modifier that requests permissions and refreshes snapshot on appear
- Added `.refreshable` for pull-to-refresh

- [ ] **Step 2: Regenerate and build**

Run: `xcodegen generate && xcodebuild build -target ambidash -sdk iphonesimulator26.5 -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run all tests**

Run: `xcrun simctl shutdown all 2>/dev/null; xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(✔|✘|Test run with|error:.*Build)"`
Expected: 19 tests pass

- [ ] **Step 4: Commit**

```bash
git add ambidash/Views/Dashboard/DashboardView.swift
git commit -m "feat: wire IntegrationManager to dashboard with auto-refresh on open"
```

---

## What This Plan Delivers

- **HealthKit integration** reading sleep, steps, workouts, and heart rate
- **EventKit integration** reading calendar events, computing free time, and counting overdue reminders
- **SnapshotBuilder** normalizing all raw data into IntegrationSnapshot (with tests)
- **IntegrationManager** coordinating everything on app open
- **Integration setup screen** in onboarding flow with permission requests
- **Dashboard auto-refresh** — real data flows into the existing QuickStatsView and DimensionBarsView on every app open, plus pull-to-refresh
- **19 total tests** (15 existing + 4 new SnapshotBuilder tests)

## What Comes Next

- **Plan 2B:** Screen Time (DeviceActivity) — requires separate app extension target
- **Plan 3:** Daily Plan + Reflection system
- **Plan 4:** Backend + AI Mentor (Claude API)
