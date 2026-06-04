import Foundation
import SwiftData

/// The app's SwiftData container, split into TWO stores:
///
///  • a synced store (CloudKit `.automatic`) for everything the user authors;
///  • a LOCAL-ONLY store (`cloudKitDatabase: .none`) that holds the HealthKit-derived
///    `IntegrationSnapshot` so sensitive health data (sleep, resting HR, steps,
///    screen time) NEVER leaves the device via iCloud.
///
/// `IntegrationSnapshot` has zero `@Relationship`s, so it can safely live in its own
/// store (relationships can't span configurations). Shared by both the iOS and macOS
/// app targets (both compile the `ambidash/` sources).
enum AppModelContainer {
    /// Everything that SHOULD sync across the user's devices.
    private static let syncedTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        CoreAssessment.self,
        WorkStylePreference.self,
        UserPreferences.self,
        Goal.self,
        DomainAssessment.self,
        GoalProgress.self,
        Streak.self,
        DailyPlan.self,
        PlannedAction.self,
        Reflection.self,
        ReflectionPhoto.self,
        MentorFeedback.self,
        ProgressLog.self,
        Milestone.self,
        Board.self,
        BoardComponent.self,
        CaptureItem.self,
        ActualEvent.self,
        EnergyCheckin.self,
        AccountabilityPartner.self,
        EncouragementMessage.self,
        CustomVital.self,
        VitalEntry.self,
        RestrictionWindow.self,
        AppBudget.self,
        RestrictionOverride.self,
    ]

    static let shared: ModelContainer = {
        let synced = ModelConfiguration(schema: Schema(syncedTypes), cloudKitDatabase: .automatic)
        let healthLocal = ModelConfiguration(
            "HealthLocal",
            schema: Schema([IntegrationSnapshot.self]),
            cloudKitDatabase: .none
        )
        let fullSchema = Schema(syncedTypes + [IntegrationSnapshot.self])
        do {
            return try ModelContainer(for: fullSchema, configurations: synced, healthLocal)
        } catch {
            // Last-ditch: an in-memory container so the app still launches rather than
            // crashing on a corrupt/incompatible store.
            return try! ModelContainer(for: fullSchema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }()
}
