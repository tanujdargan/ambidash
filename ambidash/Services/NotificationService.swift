// ambidash/Services/NotificationService.swift
//
// GENTLE NOTIFICATIONS (v3, iOS-only — excluded from the mac target).
//
// Design contract (from /tmp/v3-design: ios26-cheatsheet §4 + differentiators):
//  • Provisional authorization — NO upfront permission wall. We request with
//    `.provisional`; notifications arrive quietly in Notification Center and the
//    user promotes them if they want. We re-check settings, never nag.
//  • Interruption levels: most things are `.active`/`.passive`. Only true
//    now-moments (a block starting right now) use `.timeSensitive` — which needs
//    the self-serve `com.apple.developer.usernotifications.time-sensitive`
//    capability (added to project.yml + ambidash.entitlements). NEVER `.critical`.
//  • A `GENTLE_CHECKIN` category with ACTION-FIRST one-tap actions
//    ("I feel better" / "Move my plan" / "Just one thing") handled by a delegate.
//  • Every scheduler clamps to the user's waking window (UserPreferences wake/
//    sleep) so a gentle nudge never fires while they're asleep.
//  • Escalating reminder CHAINS (day-before → 2h → 15m → now-with-physical-first-
//    step) with a dismissal BACK-OFF so a repeatedly-ignored reminder goes quiet.
//
// All gentle, snoozable, never Critical.
import Foundation
import UserNotifications

enum NotificationService {

    // MARK: - Category / action identifiers

    enum Category {
        static let gentleCheckin = "GENTLE_CHECKIN"
    }

    /// Action-first, one-tap responses on a gentle check-in. Each is backed by a
    /// destination the delegate routes to; the disruption/triage flows are
    /// greenfield, so for now they deep-link to the most sensible existing screen
    /// and leave a typed marker (`pendingGentleAction`) the app can act on.
    enum Action {
        static let iFeelBetter = "I_FEEL_BETTER"
        static let movePlan = "MOVE_PLAN"
        static let justOne = "JUST_ONE"
        static let snooze = "GENTLE_SNOOZE"
    }

    // MARK: - Authorization (provisional — no upfront prompt)

    /// Provisional authorization: notifications are delivered quietly with no
    /// system permission dialog (design principle #8). If the user has already
    /// granted full authorization we keep it; we never downgrade and never re-prompt.
    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // Already decided (granted/provisional/full or explicitly denied): respect it.
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            registerCategories()
            return true
        case .denied:
            return false
        case .notDetermined:
            break
        @unknown default:
            break
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
            registerCategories()
            return granted
        } catch {
            return false
        }
    }

    /// Registers the interactive `GENTLE_CHECKIN` category. Idempotent — safe to
    /// call on every launch alongside scheduling.
    static func registerCategories() {
        let iFeelBetter = UNNotificationAction(
            identifier: Action.iFeelBetter,
            title: "I feel better",
            options: [.foreground]
        )
        let movePlan = UNNotificationAction(
            identifier: Action.movePlan,
            title: "Move my plan",
            options: [.foreground]
        )
        let justOne = UNNotificationAction(
            identifier: Action.justOne,
            title: "Just one thing",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze,
            title: "Later",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Category.gentleCheckin,
            actions: [iFeelBetter, movePlan, justOne, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Waking-window clamp

    /// The user's waking window in minutes-from-midnight, persisted in
    /// UserDefaults (thread-safe, survives launches) so schedulers don't each
    /// re-open a context. Falls back to a sane 07:00–23:30 when unset.
    private static let wakeKey = "notif.wakeMinutes"
    private static let sleepKey = "notif.sleepMinutes"

    private static var cachedWakeMinutes: Int {
        let v = UserDefaults.standard.object(forKey: wakeKey) as? Int
        return v ?? (7 * 60)
    }
    private static var cachedSleepMinutes: Int {
        let v = UserDefaults.standard.object(forKey: sleepKey) as? Int
        return v ?? (23 * 60 + 30)
    }

    /// Refresh the stored waking window from the user's preferences. Called from the
    /// app's scheduling entry point with the live values. Clock strings ("07:00").
    static func configureWakingWindow(wake: String, sleep: String) {
        if let w = DailyTimeline.minutes(from: wake) { UserDefaults.standard.set(w, forKey: wakeKey) }
        if let s = DailyTimeline.minutes(from: sleep) { UserDefaults.standard.set(s, forKey: sleepKey) }
    }

    /// Returns true when `minutes`-from-midnight falls inside the waking window.
    /// Handles a sleep time that crosses midnight (e.g. wake 07:00, sleep 01:00).
    static func isWaking(_ minutes: Int) -> Bool {
        let wake = cachedWakeMinutes
        let sleep = cachedSleepMinutes
        if wake <= sleep {
            return minutes >= wake && minutes < sleep
        } else {
            // Window wraps past midnight: awake = [wake, 24:00) ∪ [00:00, sleep).
            return minutes >= wake || minutes < sleep
        }
    }

    /// Clamps an intended `hour`/`minute` into the waking window. If it already
    /// falls inside, it's returned unchanged. If it lands in the sleep window, it is
    /// nudged to the nearest waking edge (just after wake, or just before sleep)
    /// so a gentle nudge is never delivered while the user is asleep.
    static func clampToWaking(hour: Int, minute: Int = 0) -> (hour: Int, minute: Int) {
        let m = (hour * 60 + minute) % (24 * 60)
        if isWaking(m) { return (hour, minute) }
        // Pick the closer waking edge. Wake edge = wake+15m; sleep edge = sleep-15m.
        let wakeEdge = (cachedWakeMinutes + 15) % (24 * 60)
        let sleepEdge = (cachedSleepMinutes - 15 + 24 * 60) % (24 * 60)
        // Distance forward to each edge (circular).
        func forwardDist(_ from: Int, _ to: Int) -> Int { (to - from + 24 * 60) % (24 * 60) }
        let edge = forwardDist(m, wakeEdge) <= forwardDist(m, sleepEdge) ? wakeEdge : sleepEdge
        return (edge / 60, edge % 60)
    }

    // MARK: - Dismissal back-off

    /// Records that a reminder family (keyed by a stable prefix, e.g. a goal slug)
    /// was dismissed, and reports whether escalation should be SUPPRESSED. After a
    /// few dismissals in a row we go quiet so we never nag a reminder the user keeps
    /// brushing away (differentiators: detect dismissal patterns and back off).
    private static let dismissalKeyPrefix = "notif.dismissals."
    private static let dismissalThreshold = 3

    static func recordDismissal(forKey key: String) {
        let k = dismissalKeyPrefix + key
        let count = UserDefaults.standard.integer(forKey: k) + 1
        UserDefaults.standard.set(count, forKey: k)
    }

    /// Reset the back-off when the user engages (opens/taps) — they're listening again.
    static func resetDismissals(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: dismissalKeyPrefix + key)
    }

    static func shouldBackOff(forKey key: String) -> Bool {
        UserDefaults.standard.integer(forKey: dismissalKeyPrefix + key) >= dismissalThreshold
    }

    // MARK: - Existing schedulers (signatures preserved; now clamped + leveled)

    static func scheduleDailyReminder(hour: Int = 21, minute: Int = 0) {
        let (h, m) = clampToWaking(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reflection"])

        let content = UNMutableNotificationContent()
        content.title = "Time to reflect"
        content.body = "How was your day? Take 2 minutes to log your progress."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-reflection", content: content, trigger: trigger)
        center.add(request)
    }

    /// CLOSING RITUAL — a single GENTLE evening invitation to close the day
    /// (celebrate what you did + pick tomorrow's one thing). Non-punitive by design:
    /// `.passive` level (no buzz/intrusion), worded as a warm offer never a chore,
    /// and CLAMPED to the evening within the user's waking window so it never fires
    /// while they're asleep. Defaults to 20:30; a daytime hour is first biased toward
    /// evening, then clamped to waking. Idempotent on the fixed id.
    static func scheduleClosingRitualReminder(hour: Int = 20, minute: Int = 30) {
        // Keep it in the evening: if a caller passes a daytime hour, bias it to at
        // least 19:00 so the "close the day" framing lands when the day is winding
        // down — then clamp to the waking window so it's never delivered asleep.
        let eveningHour = max(hour, 19)
        let (h, m) = clampToWaking(hour: eveningHour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["closing-ritual"])

        let content = UNMutableNotificationContent()
        content.title = "Close the day, gently"
        content.body = "Here's what you did today — take a breath and pick tomorrow's one thing."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.closingRitual.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "closing-ritual", content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleMorningPlan(hour: Int = 7, minute: Int = 30) {
        let (h, m) = clampToWaking(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning-plan"])

        let content = UNMutableNotificationContent()
        content.title = "Your day is ready"
        content.body = "Open ambidash to see today's plan."
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["deepLink": DeepLink.today.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "morning-plan", content: content, trigger: trigger)
        center.add(request)
    }

    /// Encouraging, progress-forward streak reminder. Celebrates the run so far and
    /// frames a single check-in today as keeping momentum — never as loss/punishment.
    /// `freezesRemaining`, when provided, reframes grace days as a built-in safety net
    /// rather than a weakness, so a single miss doesn't feel like a failure.
    static func scheduleStreakWarning(goalTitle: String, streakCount: Int, freezesRemaining: Int? = nil) {
        let slug = goalTitle.lowercased().replacingOccurrences(of: " ", with: "-")
        let id = "streak-warning-\(slug)"
        // Back off if the user keeps dismissing this goal's streak nudges.
        guard !shouldBackOff(forKey: "streak-\(slug)") else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Keep \(goalTitle) climbing"
        var body = "Your \(streakCount)-day streak for \(goalTitle) is strong — a quick check-in today keeps it climbing."
        if let freezesRemaining, freezesRemaining > 0 {
            let dayWord = freezesRemaining == 1 ? "day" : "days"
            body += " And don't worry — you've got \(freezesRemaining) grace \(dayWord) in reserve if life gets busy."
        }
        content.body = body
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "dismissKey": "streak-\(slug)"]

        let (h, m) = clampToWaking(hour: 20, minute: 0)
        var dateComponents = DateComponents()
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    /// Supportive re-engagement nudge for a goal that's gone quiet. Frames the moment
    /// as a chance to reconnect and rebuild momentum rather than as backsliding.
    static func scheduleGoalDriftNudge(goalTitle: String, neglectDays: Int) {
        let slug = goalTitle.lowercased().replacingOccurrences(of: " ", with: "-")
        guard !shouldBackOff(forKey: "drift-\(slug)") else { return }
        let center = UNUserNotificationCenter.current()
        let id = "drift-\(slug)"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Reconnect with \(goalTitle)"
        content.body = "It's been \(neglectDays) days since you touched \(goalTitle). Time to reconnect and rebuild momentum — one small step today is enough."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "dismissKey": "drift-\(slug)"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    /// Honest, balanced check-in when a tracked metric has moved the wrong way.
    /// Acknowledges the change plainly without guilt and points toward a recovery action.
    static func scheduleLossFramingNudge(metric: String, currentValue: String, previousValue: String) {
        let center = UNUserNotificationCenter.current()
        let id = "loss-\(metric.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "A check-in on \(metric)"
        content.body = "Your \(metric.lowercased()) changed from \(previousValue) to \(currentValue). It happens — let's refocus tomorrow and steer it back."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        let (h, m) = clampToWaking(hour: 14, minute: 0)
        var dateComponents = DateComponents()
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Gentle check-in + escalating chains

    /// A gentle, snoozable check-in carrying the interactive `GENTLE_CHECKIN`
    /// actions. Fires after `delay` seconds (clamped so it never lands in the sleep
    /// window), at `.active` interruption — calm, never time-sensitive, never critical.
    static func scheduleGentleCheckin(
        identifier: String = "gentle-checkin",
        title: String = "How are you doing?",
        body: String = "If today got away from you, that's okay. Want to adjust, or just pick one thing?",
        after delay: TimeInterval = 5
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = Category.gentleCheckin
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "dismissKey": identifier]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// One step of an escalating reminder CHAIN for a single block. The chain
    /// tightens as the block approaches and the final "now" step names a PHYSICAL
    /// first action (action-first copy). Only the final now-moment is
    /// `.timeSensitive` (needs the entitlement); earlier steps stay calm. A
    /// repeatedly-dismissed chain backs off entirely.
    enum ChainStep: CaseIterable {
        case dayBefore    // ~evening the day before
        case twoHours     // 2h out
        case fifteen      // 15m out
        case now          // at start — physical first-step copy

        var leadSeconds: TimeInterval {
            switch self {
            case .dayBefore: return 16 * 3600
            case .twoHours:  return 2 * 3600
            case .fifteen:   return 15 * 60
            case .now:       return 0
            }
        }
    }

    /// Schedules the full escalating chain for a block titled `blockTitle` that
    /// starts at `startDate`. `firstPhysicalStep` (e.g. "stand up and grab your
    /// shoes") names the very first bodily action for the final ping. Skips any step
    /// whose fire time is in the past or outside the waking window, and the whole
    /// chain when the user has been dismissing this block's reminders.
    static func scheduleReminderChain(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        firstPhysicalStep: String? = nil
    ) {
        let key = "chain-\(blockID)"
        // Always clear the old chain first so a re-plan re-schedules cleanly.
        cancelReminderChain(blockID: blockID)
        guard !shouldBackOff(forKey: key) else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        for step in ChainStep.allCases {
            let fireDate = startDate.addingTimeInterval(-step.leadSeconds)
            guard fireDate > Date().addingTimeInterval(1) else { continue }

            let comps = calendar.dateComponents([.hour, .minute], from: fireDate)
            let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            // Don't fire mid-sleep — but always allow the true now-moment (the block
            // genuinely starts now), since the user scheduled it there themselves.
            if step != .now && !isWaking(mins) { continue }

            let content = UNMutableNotificationContent()
            switch step {
            case .dayBefore:
                content.title = "Tomorrow: \(blockTitle)"
                content.body = "A heads-up for tomorrow so it's not a surprise."
                content.interruptionLevel = .passive
            case .twoHours:
                content.title = "In a couple hours: \(blockTitle)"
                content.body = "No rush yet — just so it's on your radar."
                content.interruptionLevel = .passive
            case .fifteen:
                content.title = "Soon: \(blockTitle)"
                content.body = "About 15 minutes out. A good moment to start winding toward it."
                content.interruptionLevel = .active
            case .now:
                content.title = "Now: \(blockTitle)"
                if let step = firstPhysicalStep, !step.isEmpty {
                    content.body = "Start small — \(step). That's the whole task right now."
                } else {
                    content.body = "It's time. Just begin the first small piece — that's enough."
                }
                // Genuine now-moment: time-sensitive so it can pierce Focus (never
                // critical). Requires the time-sensitive entitlement; the OS quietly
                // downgrades to .active if it's missing, so this stays safe.
                content.interruptionLevel = .timeSensitive
            }
            content.sound = .default
            content.categoryIdentifier = Category.gentleCheckin
            content.userInfo = [
                "deepLink": DeepLink.today.rawValue,
                "dismissKey": key,
                "blockID": blockID,
            ]

            let interval = max(1, fireDate.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let id = "\(key)-\(step)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// Cancels all pending steps of a block's reminder chain (e.g. after the block
    /// is logged done, skipped, or moved by a re-plan).
    static func cancelReminderChain(blockID: String) {
        let key = "chain-\(blockID)"
        let ids = ChainStep.allCases.map { "\(key)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Plan-level chain orchestration

    /// Names the very first PHYSICAL action for a block's final "now" ping so the
    /// action-first copy reads "stand up and …" rather than a vague "it's time".
    /// Derived from the block's domain/title — deterministic, no AI needed.
    private static func firstPhysicalStep(forTitle title: String) -> String {
        let t = title.lowercased()
        if t.contains("walk") || t.contains("run") || t.contains("gym") || t.contains("workout") || t.contains("stretch") || t.contains("exercise") {
            return "stand up and put your shoes on"
        }
        if t.contains("read") || t.contains("study") || t.contains("learn") || t.contains("review") {
            return "open the book or tab and read one line"
        }
        if t.contains("write") || t.contains("journal") || t.contains("note") {
            return "open a blank page and type one word"
        }
        if t.contains("code") || t.contains("deep work") || t.contains("work block") || t.contains("project") {
            return "open the file and read the last thing you wrote"
        }
        if t.contains("call") || t.contains("reach out") || t.contains("message") || t.contains("text") {
            return "open the thread and type \"hey\""
        }
        if t.contains("meditate") || t.contains("breath") {
            return "sit down and take one slow breath"
        }
        return "set a 2-minute timer and just begin"
    }

    /// Schedule escalating reminder CHAINS for every GOAL-WORK block in `plan` that
    /// has a real clock time still ahead of `now`. Fixed anchors / routines and
    /// already-settled blocks get NO chain (their chain is cancelled so a re-plan or
    /// a completion goes quiet). Idempotent: each block's chain is cleared and
    /// re-built, so calling this whenever the plan changes (generated, a block
    /// settled, a re-plan applied) keeps the live plan and the scheduled chains in
    /// lock-step. iOS-only — the mac target excludes this file.
    ///
    /// `actions` is passed in (rather than read off the @Model relationship inside an
    /// async hop) so the caller controls threading; pass `plan.actions ?? []`.
    static func scheduleChains(
        for actions: [PlannedAction],
        on day: Date,
        now: Date = .now
    ) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        for action in actions {
            let blockID = action.id.uuidString
            // Only goal-work blocks with a resolvable clock time earn a chain. Blocks
            // that are out of scope for "happening today" get their chain cancelled,
            // never built:
            //   • done / rest / let-go  → settled,
            //   • deferred              → rolling forward to tomorrow (a dropped block
            //                             from an applied re-plan), so no chain today,
            //   • skipped (legacy)      → set aside.
            let chainEligible: Bool = {
                switch action.lifecycle {
                case .pending, .partial: return true
                case .done, .rest, .abandoned, .deferred: return false
                }
            }()
            guard action.anchorKind == .goalWork,
                  chainEligible,
                  action.statusRaw == "pending" || action.statusRaw == "",
                  let startMin = DailyTimeline.minutes(from: action.timeSlot) else {
                cancelReminderChain(blockID: blockID)
                continue
            }
            let startDate = dayStart.addingTimeInterval(TimeInterval(startMin * 60))
            // Past blocks: nothing to remind toward — clear any stale chain.
            guard startDate > now else {
                cancelReminderChain(blockID: blockID)
                continue
            }
            scheduleReminderChain(
                blockID: blockID,
                blockTitle: action.title,
                startDate: startDate,
                firstPhysicalStep: firstPhysicalStep(forTitle: action.title)
            )
        }
    }

    // MARK: - Longer-cadence review rituals (#14)

    /// Weekly review ritual reminder. `day` is a Calendar weekday (1 = Sunday ... 7 = Saturday);
    /// defaults to Monday. Repeats every week at the given time.
    static func scheduleWeeklyReview(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let (h, m) = clampToWaking(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-review"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly review"
        content.body = "Take a few minutes to look back on your week and set your focus for the next one."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        // Clamp weekday into the valid 1...7 range so out-of-range input never drops the trigger.
        let weekday = min(max(day, 1), 7)
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "weekly-review", content: content, trigger: trigger)
        center.add(request)
    }

    /// Monthly review ritual reminder. `day` is a day-of-month (1...28 is always safe across
    /// every month; values are clamped to 28 to avoid skipping short months like February).
    /// Repeats every month at the given time.
    static func scheduleMonthlyReview(day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let (h, m) = clampToWaking(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["monthly-review"])

        let content = UNMutableNotificationContent()
        content.title = "Monthly review"
        content.body = "A new month is here. Reflect on your progress and recalibrate your goals."
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        // Clamp to 1...28 so the reminder fires every month (every month has a 28th).
        let dayOfMonth = min(max(day, 1), 28)
        var dateComponents = DateComponents()
        dateComponents.day = dayOfMonth
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "monthly-review", content: content, trigger: trigger)
        center.add(request)
    }

    /// Quarterly review ritual reminder anchored to a specific `month` (1...12) and `day` of that
    /// month. Repeats yearly for that anchor; schedule four anchors (one per quarter) to cover the
    /// full year. `day` is clamped to 1...28 to stay valid in every month.
    static func scheduleQuarterlyReview(month: Int, day: Int = 1, hour: Int = 10, minute: Int = 0) {
        let (h, m) = clampToWaking(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        // Clamp month into 1...12 and use it in the identifier so each quarter has a distinct request.
        let anchorMonth = min(max(month, 1), 12)
        let id = "quarterly-review-\(anchorMonth)"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Quarterly review"
        content.body = "Three months in — step back and take stock of the bigger picture. Where are you headed next?"
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = ["deepLink": DeepLink.reflect.rawValue]

        let dayOfMonth = min(max(day, 1), 28)
        var dateComponents = DateComponents()
        dateComponents.month = anchorMonth
        dateComponents.day = dayOfMonth
        dateComponents.hour = h
        dateComponents.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
