# Ambidash v3 — architecture & extension guide

A map of the v3 "life-OS" layer for anyone extending it. v3 is **generic + deeply customizable + neurodivergent-first**: a sensible opinionated default that anyone can reshape.

## The 10 design principles (hold these in every change)
1. **Never punish.** No red / "overdue" / failure cues for user misses — ever. Missed/past items fade via the shared `deferred` theme token (`ResolvedTheme.deferred`). `danger` is reserved for real errors + destructive actions only.
2. Strong generic defaults + progressive, bounded customization.
3. Make time visible & spatial (block timeline, not a checklist).
4. Low-friction capture (<2s, no category required).
5. Ambient over interruptive (widgets, Live Activity, gentle nudges).
6. Energy-budgeted, not just clock-budgeted (spoons).
7. Gentle, rhythm-aware nudges — Time-Sensitive, never Critical.
8. Permission-respectful, contextual onboarding (provisional auth first).
9. Privacy by construction — personal data lives only in the user's private store; never in code/logs/commits.
10. One concrete next thing on overwhelm.

## Layers (each a commit)
- **Dashboard** — configurable Notion-style board.
- **Time + capture** — non-punitive token, `DailyTimelineComponent`, Capture Inbox.
- **Adaptive engine** — logging → on-device learning → feeds plan generation.
- **Human moments** — gentle notifications, disruption re-plan, pattern check-ins.
- **Ambient** — Now/Next widget, Live Activity, closing ritual, alarms.
- **Delight** — focus timer, Wins Wall, "today is hard", rest bank.

## Key models (`ambidash/Models/`, all CloudKit-additive)
- `Board` / `BoardComponent` — the configurable dashboard. `BoardComponent` stores **type + config + order**, nothing about rendering. `kindRaw`/`sectionRaw`/`sizeRaw` are **strings** (forward-compat: unknown → `.unknown` → `UnavailableComponentCard`); `configJSON` is a JSON string so per-component options evolve with zero schema change.
- `CaptureItem` — universal capture inbox items (inbox/triaged/archived/dropped, burst-grouped).
- `ActualEvent` — what the user *actually* did/when (manual/inferred/health). Overnight (`end<start`) handled as `+1440`.
- `EnergyCheckin` — 1–5 spoons.
- `PlannedAction` — gained `lifecycleRaw` (pending/partial/deferred/rest/done/abandoned) + `partialProgress`, `anchorType`, `scheduleCue`, `alarmMode`. **Always mutate lifecycle via `applyLifecycle(_:)`** so `statusRaw`/`completedAt`/`partialProgress` stay in sync (setting `statusRaw="done"` directly causes the carried-item re-carry bug — see tests).

## The component registry (the seam)
To add a dashboard surface (zero migration):
1. add a `case` to `ComponentKind` (`Models/BoardTaxonomy.swift`) — string-backed.
2. add a `ComponentDescriptor` to `ComponentRegistry.allDescriptors` (`Views/Dashboard/Board/ComponentRegistry.swift`).
3. add a `case` to the `render(...)` factory returning your view.
Your component automatically appears in the add-menu, is placeable/reorderable/hideable, and syncs. Renderers receive the **`BoardData`** value struct (shared data computed ONCE at board level — never add a per-component `@Query` for shared data) or own a small `@Query` only when they mutate the store. Use the shared card chrome (`t.surface` + `t.hair` + `RoundedRectangle(14)` + padding 16) — no bespoke per-component chrome.

## Key services (`ambidash/Services/`, pure logic, on-device)
- `DailyTimeline` — turns `UserPreferences` into a fixed/routine skeleton + free gaps; feeds plan gen + disruption.
- `PlanGenerator` — concrete time-bound plans (anchors + routines + goal-work); consumes learned durations/times.
- `LearningService` — duration deltas, adherence-by-hour, real wake/sleep (`.health`-sourced), median; → `LearnedProfile`.
- `DisruptionService` — builds an in-memory `PlanDiff` (moved/dropped/**kept-one-thing**); cross-midnight-safe via `planNowMinutes`.
- `CarryOverService` — rolls deferred/partial forward neutrally; `.rest`/`.abandoned`/`.done` excluded.
- `WinsService` / `RestBankService` / `HardModeService` / `ClosingRitualService` — delight layer.
- `NotificationService` — provisional auth, `GENTLE_CHECKIN` action-first category, waking-hours clamp, dismissal back-off.
- `AlarmService` / `LiveActivityService` / `FocusSoundService` — ambient (AlarmKit/ActivityKit iOS-26-gated with fallbacks).

## Cross-platform
iOS-only frameworks (`ActivityKit`, `AlarmKit`, HealthKit, EventKit, ScreenTime, WidgetKit, UIKit) are `#if os(iOS)`-guarded or excluded from the `ambidash-mac` target. New `@Model`s must register in **both** `AmbidashApp.swift` and `AmbidashMacApp.swift` containers (mismatch corrupts CloudKit).

## Tests
`ambidashTests/Services/V3*.swift` — 60+ regression/happy-path tests (lifecycle no-re-carry, overnight durations, DST math, disruption keeps-one-thing, rest-bank floor, config round-trip, board seeding, wins, learning). `V3TestSupport.makeContainer()` = in-memory `ModelContainer`. Run: `xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Pending (need Apple approval / a 2nd device — not buildable-and-testable yet)
- **App-blocking** (Family Controls — request the **distribution entitlement** early; multi-week Apple approval).
- **Accountability sharing** (CloudKit summary-zone `CKShare`, opt-in summaries only).
- **Body-doubling** (SharePlay `GroupActivities`).
- Test AlarmKit on a real device (Simulator sound differs).
