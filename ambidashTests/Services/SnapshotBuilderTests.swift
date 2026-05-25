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
