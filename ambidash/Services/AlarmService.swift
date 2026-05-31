// ambidash/Services/AlarmService.swift
//
// GENTLE TIMELINE ALARMS (v3, iOS-only — excluded from the mac target).
//
// Lets a user opt a single timeline block into a genuinely-unmissable alarm at its
// START, while keeping the calm gentle-notification path as the default floor.
//
// Design contract (/tmp/v3-design/ios26-cheatsheet §1 + the non-punitive ethos):
//  • DEFAULT is GENTLE. The opt-in hard alarm is strictly per-block and never the
//    default — overriding Silent/Focus is too aggressive for a calm app, so it's
//    only used when the user explicitly asks for it on a block.
//  • iOS 26 (#available): a genuine AlarmKit `.alarm` fired at the block's start,
//    overriding Silent + Focus, system-drawn Stop/Snooze on the Lock Screen and
//    Dynamic Island. Requires `NSAlarmKitUsageDescription` + AlarmKit authorization.
//  • Pre-iOS-26 FALLBACK: a single `.timeSensitive` UNNotification at the block's
//    start, clearly LABELLED as a reminder (never dressed up as a system alarm).
//    `.timeSensitive` pierces Focus but NOT Silent — honest about what it is.
//  • The gentle path itself reuses the existing escalating notification chain
//    (NotificationService.scheduleChains) for goal-work; for any OTHER block opted
//    into "gentle" we drop a single calm start reminder here.
//
// All ids are derived deterministically from the block's UUID so a re-plan / a log
// cleanly cancels and rebuilds, and an AlarmKit alarm can be matched back to its
// PlannedAction.
import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

enum AlarmService {

    // MARK: - Identifiers

    /// The single-shot fallback / gentle UNNotification id for a block.
    private static func notificationID(blockID: String) -> String { "block-alarm-\(blockID)" }

    /// Deterministically derive the AlarmKit alarm UUID from the block UUID so a
    /// re-plan/cancel can target it without persisting a side table. Falls back to a
    /// fresh UUID if the block id isn't a UUID string (it always is in practice).
    private static func alarmUUID(blockID: String) -> UUID {
        UUID(uuidString: blockID) ?? UUID()
    }

    // MARK: - Public scheduling entry point

    /// Reconcile the per-block alarm/reminder for `action` so its scheduled surface
    /// matches its `alarmMode` and start time. Idempotent: always clears the prior
    /// alarm + fallback first, then (re)schedules per the mode. Call this from the
    /// same seam that schedules the gentle notification chains (plan generated, a
    /// block settled, a re-plan applied). `startDate` is the block's start today.
    ///
    /// `gentleHandledByChain` is true for goal-work blocks, whose `gentle` reminder
    /// is already delivered by NotificationService's escalating chain — so we don't
    /// double up a second gentle ping for them; we only act here for `alarm` or for
    /// `gentle` on non-chain blocks.
    ///
    /// `isAnchorDefault` is true for a fixed/routine anchor still on its FIELD DEFAULT
    /// (`gentle`) — i.e. an anchor the user never touched. The calm/non-punitive ethos
    /// makes the silent floor (no start reminder) the default for anchors: shipping a
    /// notification at the start of wake, every meal, commute, routine, sleep, etc. with
    /// zero opt-in is too loud. So a default-gentle anchor schedules NOTHING here; only an
    /// EXPLICIT `gentle`/`alarm` opt-in (or goal-work's own chain) produces a surface.
    static func reconcile(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        mode: PlannedAction.AlarmMode,
        gentleHandledByChain: Bool,
        isAnchorDefault: Bool = false,
        now: Date = .now
    ) {
        // Always clear any previously-scheduled surface for this block first.
        cancel(blockID: blockID)

        // Nothing to schedule for a past block or one that's turned off.
        guard mode != .off, startDate > now.addingTimeInterval(1) else { return }

        switch mode {
        case .off:
            return
        case .gentle:
            // A fixed/routine anchor still on the field default fires NOTHING — the
            // anchor floor is silent unless the user explicitly opts in.
            if isAnchorDefault { return }
            // Goal-work blocks already get the escalating gentle chain — don't add a
            // second gentle ping. For every other block (fixed anchor / routine the
            // user opted in), drop one calm start reminder.
            if gentleHandledByChain { return }
            scheduleGentleReminder(blockID: blockID, blockTitle: blockTitle, startDate: startDate, now: now)
        case .alarm:
            scheduleHardAlarm(blockID: blockID, blockTitle: blockTitle, startDate: startDate, now: now)
        }
    }

    /// Cancel both the UNNotification fallback/gentle reminder AND any AlarmKit alarm
    /// for a block (e.g. it was logged, deferred, or its mode changed). Safe to call
    /// for any block regardless of its current state.
    static func cancel(blockID: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID(blockID: blockID)])
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            try? AlarmManager.shared.cancel(id: alarmUUID(blockID: blockID))
        }
        #endif
    }

    // MARK: - Gentle path (single calm start reminder for non-chain blocks)

    /// A single, calm `.active` start reminder for a block the user opted into
    /// "gentle" that isn't covered by the goal-work chain (e.g. a fixed anchor like
    /// "wake up", a routine). Not time-sensitive — it's a soft nudge, not a now-moment
    /// escalation; the chain owns the escalating goal-work path.
    private static func scheduleGentleReminder(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        now: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = blockTitle
        content.body = "It's time, gently — \(blockTitle.lowercased())."
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "blockID": blockID]

        let interval = max(1, startDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(blockID: blockID),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Hard alarm path (AlarmKit iOS 26, time-sensitive reminder fallback)

    /// The opt-in UNMISSABLE start alarm. On iOS 26 this is a genuine AlarmKit alarm
    /// (overrides Silent + Focus, system Stop/Snooze). Pre-26 it degrades to a
    /// `.timeSensitive` reminder, clearly LABELLED as a reminder so we never pretend a
    /// notification is a system alarm.
    private static func scheduleHardAlarm(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        now: Date
    ) {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            Task { await scheduleAlarmKit(blockID: blockID, blockTitle: blockTitle, startDate: startDate) }
            return
        }
        #endif
        scheduleTimeSensitiveFallback(blockID: blockID, blockTitle: blockTitle, startDate: startDate, now: now)
    }

    /// Pre-26 fallback: a single `.timeSensitive` notification at the block start,
    /// labelled honestly as a reminder. `.timeSensitive` needs the self-serve
    /// `com.apple.developer.usernotifications.time-sensitive` capability (already
    /// granted); without it the OS quietly downgrades to `.active`, so this stays safe.
    private static func scheduleTimeSensitiveFallback(
        blockID: String,
        blockTitle: String,
        startDate: Date,
        now: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(blockTitle)"
        content.body = "Your block is starting now. (Tap to open — this is a reminder, not a system alarm.)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "blockID": blockID]

        let interval = max(1, startDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(blockID: blockID),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    #if canImport(AlarmKit)
    /// Schedule a genuine AlarmKit alarm at the block's start (iOS 26+). Requests
    /// authorization lazily; if the user declines we fall back to the time-sensitive
    /// reminder so the opt-in still does *something* rather than silently failing.
    @available(iOS 26.1, *)
    private static func scheduleAlarmKit(blockID: String, blockTitle: String, startDate: Date) async {
        let manager = AlarmManager.shared
        // Lazily request authorization. If declined, degrade gracefully.
        let authorized: Bool
        switch manager.authorizationState {
        case .authorized:
            authorized = true
        case .denied:
            authorized = false
        default:
            authorized = (try? await manager.requestAuthorization()) == .authorized
        }
        guard authorized else {
            scheduleTimeSensitiveFallback(blockID: blockID, blockTitle: blockTitle, startDate: startDate, now: .now)
            return
        }

        let id = alarmUUID(blockID: blockID)

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: blockTitle),
            secondaryButton: AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "zzz"
            ),
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: blockTitle),
            pauseButton: nil
        )
        let presentation = AlarmPresentation(alert: alert, countdown: countdown)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: BlockAlarmMetadata(blockTitle: blockTitle),
            tintColor: .indigo
        )

        // A short snooze countdown if the user taps Snooze.
        let countdownDuration = Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60)

        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: .fixed(startDate),
            attributes: attributes,
            stopIntent: StopBlockAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: SnoozeBlockAlarmIntent(alarmID: id.uuidString),
            sound: .default
        )

        do {
            _ = try await manager.schedule(id: id, configuration: config)
        } catch {
            // On any AlarmKit failure (limit reached, etc.) fall back so the user's
            // opt-in still produces a reminder.
            scheduleTimeSensitiveFallback(blockID: blockID, blockTitle: blockTitle, startDate: startDate, now: .now)
        }
    }
    #endif

    // MARK: - Plan-level reconciliation

    /// Reconcile every block's opt-in alarm/reminder across a plan, mirroring
    /// `NotificationService.scheduleChains`. Goal-work blocks have their `gentle`
    /// path owned by the chain (so we pass `gentleHandledByChain: true` for them);
    /// all blocks honor `alarm` here. Settled / past blocks are cancelled. Idempotent.
    static func reconcilePlan(for actions: [PlannedAction], on day: Date, now: Date = .now) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        for action in actions {
            let blockID = action.id.uuidString

            // A block is live (eligible for a future reminder/alarm) only while it's
            // still pending/partial — settled states get cancelled.
            let live: Bool = {
                switch action.lifecycle {
                case .pending, .partial: return true
                case .done, .rest, .abandoned, .deferred: return false
                }
            }()

            guard live,
                  action.statusRaw == "pending" || action.statusRaw == "",
                  let startMin = DailyTimeline.minutes(from: action.timeSlot) else {
                cancel(blockID: blockID)
                continue
            }

            let startDate = calendar.date(byAdding: .minute, value: startMin, to: dayStart) ?? dayStart.addingTimeInterval(TimeInterval(startMin * 60))
            // A fixed/routine anchor still carrying the `gentle` FIELD DEFAULT is one
            // the user never opted in: keep its start silent (the non-punitive default
            // floor for anchors). Goal-work keeps its chain; an explicit `alarm` (or a
            // gentle the user could set in future UI) still surfaces.
            let isAnchorDefault = action.anchorKind != .goalWork && action.alarmMode == .gentle
            reconcile(
                blockID: blockID,
                blockTitle: action.title,
                startDate: startDate,
                mode: action.alarmMode,
                gentleHandledByChain: action.anchorKind == .goalWork,
                isAnchorDefault: isAnchorDefault,
                now: now
            )
        }
    }
}
