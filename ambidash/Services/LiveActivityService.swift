#if os(iOS)
import Foundation
import ActivityKit

/// Drives the Now/Next focus Live Activity off the daily plan.
///
/// Design (iOS-26 cheat-sheet §2): the live countdown is rendered by the widget
/// with `Text(timerInterval:countsDown:)` against `ContentState.blockInterval`,
/// so the SYSTEM ticks it with zero app wake-ups. This service only:
///   • starts one Activity at day-begin / when the plan changes,
///   • `update()`s it at each block boundary (reusing the same `[PlannedAction]`
///     iterator the notification chains already walk), and
///   • `end(.immediate)`s it at day's end (and defensively on refresh).
///
/// Everything is local-only (`pushType: nil`) — no server, no APNs. ActivityKit
/// is iOS 16.1+, so the whole surface is gated behind `#available`; pre-16.1
/// (and the macOS target, which excludes this file) keep the static Now/Next
/// widget + the existing notification chain as the fallback.
///
/// We model a "block" as a contiguous PlannedAction with a resolvable clock
/// time. The CURRENT block is the one whose interval contains `now`; the NEXT
/// block is the soonest future one. When no block is current, we keep the
/// Activity anchored on the upcoming block so the Lock Screen still reads
/// "NOW / NEXT" calmly rather than going blank.
enum LiveActivityService {

    /// A resolved block: a PlannedAction projected onto today's clock.
    private struct Block {
        let title: String
        let domainRaw: String
        let interval: ClosedRange<Date>
    }

    /// Rebuild the Live Activity from `actions` for `day`. Idempotent: starts the
    /// Activity if none is running, updates the running one to the current block,
    /// or ends it when the day is over / there are no blocks left. Safe to call
    /// whenever the plan changes (generated, a block settled, a re-plan applied)
    /// or when the app foregrounds.
    static func refresh(for actions: [PlannedAction], on day: Date, now: Date = .now) {
        guard #available(iOS 16.1, *) else { return }
        // Respect the user's system-level Live Activities setting.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Only run for today; a stale plan from another day shouldn't post one.
        guard Calendar.current.isDate(day, inSameDayAs: now) else {
            endAll()
            return
        }

        let blocks = resolveBlocks(actions, on: day)
        let current = blocks.first { $0.interval.contains(now) }
        let upcoming = blocks
            .filter { $0.interval.lowerBound > now }
            .sorted { $0.interval.lowerBound < $1.interval.lowerBound }
        let next = upcoming.first

        // Nothing happening now and nothing left today → end any running activity.
        // The anchor is the block we count down: the current one if a block is
        // running, otherwise the soonest upcoming one. The "next" we DISPLAY is
        // then the soonest block strictly after the anchor.
        let anchor: Block
        let displayNext: Block?
        if let current {
            anchor = current
            displayNext = next                       // first block strictly after now
        } else if let next {
            anchor = next                            // nothing running → count down to the next block
            displayNext = upcoming.dropFirst().first // the one after the anchor
        } else {
            endAll()
            return
        }

        let actionsRemaining = blocks.filter { $0.interval.upperBound > now }.count
        let state = PlanBlockAttributes.ContentState(
            blockInterval: anchor.interval,
            blockTitle: anchor.title,
            blockDomainRaw: anchor.domainRaw,
            nextTitle: displayNext?.title,
            nextStart: displayNext?.interval.lowerBound,
            actionsRemaining: actionsRemaining
        )

        // Stale a little after the current block ends so a missed update reads as
        // "wrapping up" rather than a wrong countdown.
        let staleDate = anchor.interval.upperBound.addingTimeInterval(60)
        let content = ActivityContent(state: state, staleDate: staleDate)

        let dayStart = Calendar.current.startOfDay(for: day)
        if let running = Activity<PlanBlockAttributes>.activities.first {
            Task { await running.update(content) }
        } else {
            let attributes = PlanBlockAttributes(dayStart: dayStart)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    /// End every running Now/Next Activity immediately. Call at day's end, on
    /// closing ritual, or when there's no longer anything to surface.
    static func endAll() {
        guard #available(iOS 16.1, *) else { return }
        let final = PlanBlockAttributes.ContentState(
            blockInterval: Date()...Date(),
            blockTitle: "",
            blockDomainRaw: "",
            nextTitle: nil,
            nextStart: nil,
            actionsRemaining: 0
        )
        let content = ActivityContent(state: final, staleDate: nil)
        Task {
            for activity in Activity<PlanBlockAttributes>.activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Block resolution

    /// Project goal-work / routine PlannedActions onto today's clock as blocks.
    /// Only actions with a resolvable HH:mm time and that are still live (pending
    /// or partial — never done/rest/abandoned/deferred) become blocks, so a
    /// settled day collapses the Activity. The accent domain is carried as a raw
    /// string the widget maps with its own styling (no GoalDomain import needed).
    @available(iOS 16.1, *)
    private static func resolveBlocks(_ actions: [PlannedAction], on day: Date) -> [Block] {
        let dayStart = Calendar.current.startOfDay(for: day)
        return actions.compactMap { action -> Block? in
            let live: Bool = {
                switch action.lifecycle {
                case .pending, .partial: return true
                case .done, .rest, .abandoned, .deferred: return false
                }
            }()
            guard live, action.statusRaw == "pending" || action.statusRaw == "",
                  let startMin = DailyTimeline.minutes(from: action.timeSlot) else { return nil }
            let start = dayStart.addingTimeInterval(TimeInterval(startMin * 60))
            let duration = max(1, action.durationMinutes)
            let end = start.addingTimeInterval(TimeInterval(duration * 60))
            // The accent domain is left empty here (the widget renders a neutral
            // accent) to avoid a Goal fetch on this hot plan-change path; the
            // precise per-goal domain already reaches the Lock Screen / Home
            // Screen widgets via the App Group snapshot.
            return Block(
                title: action.title,
                domainRaw: "",
                interval: start...end
            )
        }
        .sorted { $0.interval.lowerBound < $1.interval.lowerBound }
    }
}
#endif
