import Foundation
import SwiftData

/// LOGGING (build-order #3) — captures what the user ACTUALLY did and when, as
/// distinct from what was PLANNED (`PlannedAction`). This is the raw substrate the
/// on-device LearningService reads to compute duration deltas, real wake/sleep, and
/// adherence-by-time — the data that lets the plan adapt to the real human instead
/// of nagging them toward an idealized one.
///
/// Sources (string-keyed, additive):
/// - `manual`   — the user logged it (one-tap "did this" on a timeline block, or a
///                free "log what you did" entry).
/// - `inferred` — auto-derived from a completed `PlannedAction` (completedAt +
///                timeSlot + duration) so logging is mostly automatic.
/// - `health`   — derived from HealthKit (real sleep/wake, workouts).
///
/// NON-PUNITIVE: a logged event is never a verdict. `completionStatusRaw` can read
/// `partial` or `abandoned` but these are honored states (2 of 5 counts), never
/// failures. Nothing here is shame-coded.
///
/// CloudKit-safe (additive-only): every scalar is defaulted, the back-link to the
/// originating PlannedAction is a plain `linkedActionID: UUID?` (NOT a relationship,
/// so no relationship migration), and the source/status/energy enums are
/// STRING-keyed with safe fallbacks. Registered in BOTH ModelContainers
/// (AmbidashApp.swift + AmbidashMacApp.swift).
///
/// PRIVACY: this is personal behavioral data. It lives ONLY in the user's private
/// SwiftData/iCloud store — never logged, never in crash reports, never shared
/// except as opted-in aggregates.
@Model
final class ActualEvent: Identifiable {
    var id: UUID = UUID()

    /// What the user did, in their own words (or the planned action's title when
    /// auto-inferred). Empty for a bare time-only log.
    var title: String = ""

    /// Minutes-from-midnight the event started / ended (local). Mirrors the
    /// timeline's minute model so deltas against a `PlannedAction` are trivial.
    var startMinutes: Int = 0
    var endMinutes: Int = 0

    /// The calendar day this event belongs to (start-of-day). Used to bucket events
    /// for per-day adherence and wake/sleep inference.
    var date: Date = Date()

    /// Where this record came from (resolved to `ActualEventSource`, unknown →
    /// `.manual`). manual / inferred / health.
    var sourceRaw: String = "manual"

    /// How the event resolved (resolved to `ActualCompletionStatus`, unknown →
    /// `.completed`). completed / partial / abandoned — all honored, none shamed.
    var completionStatusRaw: String = "completed"

    /// The energy the user reported at the START of this event, if they logged one
    /// (1–5; 0 = not reported). Lets the learning layer correlate energy with
    /// adherence without a separate join.
    var energyAtStart: Int = 0

    /// Optional free note ("ran long because…", "felt great"). Never required.
    var notes: String = ""

    /// The `PlannedAction.id` this event corresponds to, if it was logged against a
    /// planned block. Plain UUID? (NOT a relationship) to keep the CloudKit surface
    /// additive. nil for an unplanned actual ("I did this, it wasn't on the plan").
    var linkedActionID: UUID?

    /// The `Goal.id` this event advanced, if any. Carried from the planned action so
    /// aggregates can roll up by goal without re-joining through the plan.
    var linkedGoalID: UUID?

    /// When this record was created (distinct from `startMinutes`, which is when the
    /// activity happened). Lets us tell "logged live" from "logged after the fact".
    var loggedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String = "",
        startMinutes: Int = 0,
        endMinutes: Int = 0,
        date: Date = .now,
        sourceRaw: String = "manual",
        completionStatusRaw: String = "completed",
        energyAtStart: Int = 0,
        notes: String = "",
        linkedActionID: UUID? = nil,
        linkedGoalID: UUID? = nil,
        loggedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.date = date
        self.sourceRaw = sourceRaw
        self.completionStatusRaw = completionStatusRaw
        self.energyAtStart = energyAtStart
        self.notes = notes
        self.linkedActionID = linkedActionID
        self.linkedGoalID = linkedGoalID
        self.loggedAt = loggedAt
    }

    // MARK: - Runtime resolution (raw string → enum, safe fallbacks)

    var source: ActualEventSource {
        get { ActualEventSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var completionStatus: ActualCompletionStatus {
        get { ActualCompletionStatus(rawValue: completionStatusRaw) ?? .completed }
        set { completionStatusRaw = newValue.rawValue }
    }

    /// Actual duration in minutes (clamped non-negative). The signal the learning
    /// layer compares against the plan's `durationMinutes`.
    ///
    /// Overnight events (a sleep block recorded as start=bedtime, end=next-morning
    /// wake) have `endMinutes < startMinutes`. A naive `end - start` clamps that to 0
    /// and erases the whole night. Special-case it: when the end-of-day minute is
    /// before the start, the event crossed midnight, so add a full day (+1440) to the
    /// end before differencing.
    var actualDurationMinutes: Int {
        let raw = endMinutes - startMinutes
        if raw < 0 { return (endMinutes + 1440) - startMinutes }   // crossed midnight
        return raw
    }
}

// MARK: - String-keyed enums (additive / forward-compatible)

/// Where an `ActualEvent` record came from. STRING-keyed so new sources are
/// additive and an older client resolves an unknown value to `.manual`.
enum ActualEventSource: String, CaseIterable, Codable, Hashable {
    case manual
    case inferred
    case health
}

/// How an `ActualEvent` resolved. All three are HONORED states — `partial` and
/// `abandoned` are legitimate, never failures. STRING-keyed, unknown → `.completed`.
enum ActualCompletionStatus: String, CaseIterable, Codable, Hashable {
    case completed
    case partial
    case abandoned

    /// Calm, non-punitive label for the logging UI.
    var label: String {
        switch self {
        case .completed: return "Did it"
        case .partial: return "Partly"
        case .abandoned: return "Didn't, that's okay"
        }
    }
}
