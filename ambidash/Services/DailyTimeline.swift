// ambidash/Services/DailyTimeline.swift
import Foundation

/// PLAN REWRITE — turns the user's `UserPreferences` (their real daily rhythm)
/// into a concrete, time-ordered SKELETON of the day: fixed anchors (wake, meals,
/// work/class blocks, sleep) and daily routines (morning routine, workout, cook
/// dinner). Goal-work is then slotted into the FREE GAPS between these entries.
///
/// This is the shared source of truth for both paths:
/// - the OFFLINE planner (`PlanGenerator`) weaves goal-work into the gaps these
///   entries leave open, then emits one merged timeline.
/// - the AI planner renders this skeleton into the prompt so the model fills the
///   same gaps with concrete, time-bound goal-work instead of abstract nags.
///
/// Every entry reads like a real instruction: a clock time or relative cue + a
/// concrete title + a duration. No abstract phrasing.
enum DailyTimeline {

    /// One entry in the day's fixed/routine skeleton.
    struct Entry {
        /// "fixed" or "routine" — maps to PlannedAction.anchorType.
        let kind: PlannedAction.AnchorKind
        /// Instruction-style title, e.g. "No phone, make breakfast", "Cook dinner".
        let title: String
        /// Sortable HH:MM start used to order the timeline and assign slots.
        let startMinutes: Int
        /// Display cue when not a hard clock time, e.g. "Before 13:00", "After class".
        /// Empty means show the clock time from `startMinutes`.
        let scheduleCue: String
        /// Minutes this entry occupies. Used to find the gaps for goal-work.
        let durationMinutes: Int
        /// Short why/reason line.
        let why: String

        var clock: String { Self.format(startMinutes) }
        var endMinutes: Int { startMinutes + durationMinutes }

        static func format(_ minutes: Int) -> String {
            let m = ((minutes % (24 * 60)) + 24 * 60) % (24 * 60)
            return String(format: "%02d:%02d", m / 60, m % 60)
        }
    }

    /// A free gap between skeleton entries where goal-work can be slotted.
    struct Gap {
        let startMinutes: Int
        let endMinutes: Int
        var minutes: Int { max(0, endMinutes - startMinutes) }
    }

    // MARK: - Time parsing

    /// Parses an "HH:mm" (or "H:mm") clock string into minutes-from-midnight.
    /// Tolerates en-dash ranges by taking the first time. Returns nil when no time
    /// can be read, so callers can fall back to a default.
    static func minutes(from clock: String) -> Int? {
        let trimmed = clock.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Take the leading time token (handles "09:00–17:00" → "09:00").
        let firstToken = trimmed.split(whereSeparator: { "–—-".contains($0) }).first.map(String.init) ?? trimmed
        let parts = firstToken.split(separator: ":")
        guard let h = Int(parts.first ?? "") else { return nil }
        let m = parts.count > 1 ? (Int(parts[1].prefix(2)) ?? 0) : 0
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    /// Splits a free-text routine ("skincare, oral care, no phone first 30 min")
    /// into a compact, readable label. Keeps it short for an instruction title.
    private static func compact(_ text: String, limit: Int = 64) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: ", ")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.count <= limit { return cleaned }
        return String(cleaned.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - Skeleton

    /// Builds the day's fixed-anchor + routine skeleton from the user's prefs,
    /// time-ordered. Returns an empty array when no prefs are set, so the caller
    /// falls back to a goal-work-only plan.
    static func skeleton(from prefs: UserPreferences?) -> [Entry] {
        guard let p = prefs else { return [] }

        let wake = minutes(from: p.wakeTime) ?? (7 * 60)
        let sleep = minutes(from: p.sleepTime) ?? (23 * 60 + 30)
        var entries: [Entry] = []

        // Morning routine — anchored at wake, instruction-style. Pulls the user's
        // own words (e.g. "skincare, oral care, no phone first 30 min").
        if !p.morningRoutine.trimmingCharacters(in: .whitespaces).isEmpty {
            entries.append(Entry(
                kind: .routine,
                title: "Morning routine — \(compact(p.morningRoutine))",
                startMinutes: wake,
                scheduleCue: "",
                durationMinutes: 30,
                why: "Start the day on your terms, not your phone's"
            ))
        } else {
            entries.append(Entry(
                kind: .fixed, title: "Wake up", startMinutes: wake,
                scheduleCue: "", durationMinutes: 5, why: "The day starts here"
            ))
        }

        // Breakfast.
        if let b = minutes(from: p.breakfastTime) {
            entries.append(Entry(
                kind: .fixed, title: "Have breakfast", startMinutes: b,
                scheduleCue: "", durationMinutes: 20, why: "Fuel before the day picks up"
            ))
        }

        // Work / class busy block — a fixed wall the day is built around.
        if !p.workBusyBlock.trimmingCharacters(in: .whitespaces).isEmpty,
           let workStart = minutes(from: p.workBusyBlock) {
            // Try to read the block's end for accurate gap math.
            let workEnd = blockEndMinutes(from: p.workBusyBlock) ?? (workStart + 8 * 60)
            entries.append(Entry(
                kind: .fixed,
                title: p.workBusyBlock.trimmingCharacters(in: .whitespaces),
                startMinutes: workStart,
                scheduleCue: "",
                durationMinutes: max(60, workEnd - workStart),
                why: "Your fixed work/class block"
            ))
        }

        // Lunch — phrased as a soft deadline so it reads as an instruction.
        if let l = minutes(from: p.lunchTime) {
            entries.append(Entry(
                kind: .fixed, title: "Have lunch", startMinutes: l,
                scheduleCue: "Before \(Entry.format(l))", durationMinutes: 30,
                why: "Eat on time — don't skip it"
            ))
        }

        // Workout — after the work block when possible.
        if p.worksOut, let w = minutes(from: p.workoutTime) {
            let type = p.workoutType.trimmingCharacters(in: .whitespaces)
            let title = type.isEmpty ? "Workout" : "Workout — \(type)"
            entries.append(Entry(
                kind: .routine, title: title, startMinutes: w,
                scheduleCue: workoutCue(p), durationMinutes: 45,
                why: "Move your body — it carries everything else"
            ))
        }

        // Cook dinner — pulled from prefs; otherwise just "have dinner".
        if let d = minutes(from: p.dinnerTime) {
            if p.cooksOwnMeals {
                entries.append(Entry(
                    kind: .routine, title: "Cook dinner", startMinutes: d,
                    scheduleCue: "", durationMinutes: 40,
                    why: "Cooking for yourself is a small daily win"
                ))
            } else {
                entries.append(Entry(
                    kind: .fixed, title: "Have dinner", startMinutes: d,
                    scheduleCue: "", durationMinutes: 30, why: "Refuel for the evening"
                ))
            }
        }

        // Evening routine + sleep.
        if !p.eveningRoutine.trimmingCharacters(in: .whitespaces).isEmpty {
            let windDown = max(wake, sleep - 45)
            entries.append(Entry(
                kind: .routine,
                title: "Evening routine — \(compact(p.eveningRoutine))",
                startMinutes: windDown, scheduleCue: "", durationMinutes: 30,
                why: "Wind down so tomorrow starts clean"
            ))
        }
        entries.append(Entry(
            kind: .fixed, title: "Lights out — sleep", startMinutes: sleep,
            scheduleCue: "By \(Entry.format(sleep))", durationMinutes: 5,
            why: "Protect tomorrow's energy"
        ))

        return entries.sorted { $0.startMinutes < $1.startMinutes }
    }

    /// A relative cue for the workout based on whether it lands right after the
    /// work/class block. "After class" reads better than a clock time when it does.
    private static func workoutCue(_ p: UserPreferences) -> String {
        guard let w = minutes(from: p.workoutTime),
              let workEnd = blockEndMinutes(from: p.workBusyBlock) else { return "" }
        // Within 90 min of the work block ending → frame as "after …".
        if w >= workEnd && w - workEnd <= 90 {
            let lower = p.workBusyBlock.lowercased()
            if lower.contains("class") { return "After class" }
            if lower.contains("work") || lower.contains("office") { return "After work" }
        }
        return ""
    }

    /// Reads the END time of a busy-block string like "09:00–17:00 class".
    private static func blockEndMinutes(from block: String) -> Int? {
        let tokens = block.split(whereSeparator: { "–—-".contains($0) })
        guard tokens.count >= 2 else { return nil }
        return minutes(from: String(tokens[1]))
    }

    // MARK: - Gaps

    /// The free gaps between skeleton entries within the waking window, where
    /// goal-work can be slotted. Merges overlapping entries and only returns gaps
    /// of at least `minGap` minutes. When the skeleton is empty, returns one big
    /// gap across the default waking window so goal-work still has somewhere to go.
    static func freeGaps(in skeleton: [Entry], minGap: Int = 25) -> [Gap] {
        guard !skeleton.isEmpty else {
            return [Gap(startMinutes: 8 * 60, endMinutes: 22 * 60)]
        }
        let sorted = skeleton.sorted { $0.startMinutes < $1.startMinutes }
        let dayStart = sorted.first!.endMinutes
        let dayEnd = sorted.last!.startMinutes
        var gaps: [Gap] = []
        var cursor = dayStart
        for entry in sorted {
            if entry.startMinutes - cursor >= minGap {
                gaps.append(Gap(startMinutes: cursor, endMinutes: entry.startMinutes))
            }
            cursor = max(cursor, entry.endMinutes)
        }
        // Trailing gap before the last anchor (e.g. before sleep) if room remains.
        if dayEnd - cursor >= minGap {
            gaps.append(Gap(startMinutes: cursor, endMinutes: dayEnd))
        }
        return gaps
    }

    // MARK: - Prompt rendering

    /// Renders the skeleton as a prompt-ready block so the AI sees the EXACT
    /// fixed timeline it must build around, plus the explicit free gaps it should
    /// slot goal-work into. Empty string when no prefs, so the prompt is unchanged.
    static func promptSkeleton(from prefs: UserPreferences?) -> String {
        let entries = skeleton(from: prefs)
        guard !entries.isEmpty else { return "" }
        var out = "\nTHE DAY'S FIXED SKELETON (already set — DO NOT move these; build around them):\n"
        for e in entries {
            let when = e.scheduleCue.isEmpty ? e.clock : e.scheduleCue
            let tag = e.kind == .routine ? "[routine]" : "[fixed]"
            out += "- \(when) \(tag) \(e.title) (\(e.durationMinutes)m)\n"
        }
        let gaps = freeGaps(in: entries)
        if !gaps.isEmpty {
            out += "\nFREE GAPS for goal-work (slot concrete goal tasks into these, with a clock time or relative cue):\n"
            for g in gaps {
                out += "- \(Entry.format(g.startMinutes))–\(Entry.format(g.endMinutes)) (\(g.minutes)m free)\n"
            }
        }
        return out
    }
}
