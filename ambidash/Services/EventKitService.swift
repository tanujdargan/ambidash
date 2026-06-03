// ambidash/Services/EventKitService.swift
import Foundation
import EventKit

@MainActor
final class EventKitService {
    static let shared = EventKitService()

    private let store = EKEventStore()

    /// Real calendar authorization state for the Settings row. Reads the system's
    /// `EKEventStore.authorizationStatus(for: .event)`; both full and write-only access
    /// count as connected (the app only writes/reads events through `store`).
    var isCalendarAuthorized: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly, .authorized:
            return true
        default:
            return false
        }
    }

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
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
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
            let count = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
                let predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: .now,
                    calendars: nil
                )
                store.fetchReminders(matching: predicate) { reminders in
                    continuation.resume(returning: reminders?.count ?? 0)
                }
            }
            return count
        } catch {
            return 0
        }
    }

    // MARK: - Writes (v4 calendar integration)

    /// Adds a reminder for a goal to the user's default Reminders list. Requests
    /// access first (idempotent). Returns false if access is denied or the save
    /// fails — callers fire-and-forget and never block goal creation on this.
    @discardableResult
    func addGoalReminder(title: String, notes: String? = nil, due: Date? = nil) async -> Bool {
        guard await requestRemindersAccess() else { return false }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: due)
        }
        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// Adds a timed event to the user's default calendar (for scheduled plan
    /// blocks / dated milestones). Requests access first (idempotent).
    @discardableResult
    func addEvent(title: String, start: Date, durationMinutes: Int, notes: String? = nil) async -> Bool {
        guard await requestCalendarAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(max(durationMinutes, 5) * 60))
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }
}
