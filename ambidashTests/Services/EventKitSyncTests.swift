import Testing
import Foundation
@testable import ambidash

/// v4 #8 — calendar auto-sync. Covers the pure slot-parsing that decides whether a
/// scheduled task becomes a timed calendar event. EventKit writes themselves need a
/// device/permission, so we test the parsing boundary that gates them.
@MainActor
@Test func resolveStartParsesValidSlot() {
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 3))!
    let start = EventKitService.resolveStart(on: day, timeSlot: "14:30")
    #expect(start != nil)
    let comps = Calendar.current.dateComponents([.hour, .minute, .day], from: start!)
    #expect(comps.hour == 14)
    #expect(comps.minute == 30)
    #expect(comps.day == 3)
}

@MainActor
@Test func resolveStartRejectsEmptyAndMalformedSlots() {
    let day = Date()
    #expect(EventKitService.resolveStart(on: day, timeSlot: "") == nil)
    #expect(EventKitService.resolveStart(on: day, timeSlot: "9am") == nil)
    #expect(EventKitService.resolveStart(on: day, timeSlot: "14") == nil)
    #expect(EventKitService.resolveStart(on: day, timeSlot: "25:00") == nil)
    #expect(EventKitService.resolveStart(on: day, timeSlot: "12:75") == nil)
}
