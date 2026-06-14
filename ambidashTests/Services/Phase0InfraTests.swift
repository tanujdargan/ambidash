import Testing
import Foundation
@testable import ambidash

// Phase 0 — tests for the new on-device infra: FeatureFlags (stub gating) and
// ActivationCounters (privacy-safe funnel). Both inject an isolated UserDefaults suite.
// They mutate a shared static `store`, so they're grouped in a `.serialized` suite —
// otherwise Swift Testing's default parallelism races them (one test resets the global
// store mid-flight of another).

private func freshSuite(_ name: String) -> UserDefaults {
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Suite(.serialized)
struct Phase0InfraSuite {

    @Test func featureFlagsDefaultOffAndToggle() {
        let suite = freshSuite("test.featureflags")
        FeatureFlags.store = suite
        defer { FeatureFlags.store = .standard }

        for flag in FeatureFlag.allCases {
            #expect(FeatureFlags.isEnabled(flag) == false)   // all stubs ship OFF
            #expect(flag.defaultEnabled == false)
        }
        FeatureFlags.set(.mentorMatching, true)
        #expect(FeatureFlags.isEnabled(.mentorMatching) == true)
        #expect(FeatureFlags.isEnabled(.socialFeed) == false)   // independence
        FeatureFlags.reset(.mentorMatching)
        #expect(FeatureFlags.isEnabled(.mentorMatching) == false)
    }

    @Test func activationCounterIncrementsAndStampsFirstSeen() {
        let suite = freshSuite("test.activation")
        ActivationCounters.store = suite
        defer { ActivationCounters.store = .standard }

        #expect(ActivationCounters.count(.firstPlanGenerated) == 0)
        #expect(ActivationCounters.hasOccurred(.firstPlanGenerated) == false)
        #expect(ActivationCounters.firstOccurrence(.firstPlanGenerated) == nil)

        ActivationCounters.record(.firstPlanGenerated)
        #expect(ActivationCounters.count(.firstPlanGenerated) == 1)
        #expect(ActivationCounters.hasOccurred(.firstPlanGenerated) == true)
        let first = ActivationCounters.firstOccurrence(.firstPlanGenerated)
        #expect(first != nil)

        // Subsequent records accumulate but DON'T move the first-occurrence stamp.
        ActivationCounters.record(.firstPlanGenerated, count: 3)
        #expect(ActivationCounters.count(.firstPlanGenerated) == 4)
        #expect(ActivationCounters.firstOccurrence(.firstPlanGenerated) == first)
    }

    @Test func activationSnapshotCoversAllEventsAndResetWorks() {
        let suite = freshSuite("test.activation.snap")
        ActivationCounters.store = suite
        defer { ActivationCounters.store = .standard }

        ActivationCounters.record(.onboardingCompleted)
        ActivationCounters.record(.firstCapture, count: 2)

        let snap = ActivationCounters.snapshot()
        #expect(snap.count == ActivationEvent.allCases.count)
        #expect(snap[.firstCapture] == 2)
        #expect(snap[.firstReflection] == 0)

        ActivationCounters.reset(.firstCapture)
        #expect(ActivationCounters.count(.firstCapture) == 0)
        #expect(ActivationCounters.firstOccurrence(.firstCapture) == nil)
    }
}
