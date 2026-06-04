// ambidash/Services/DisruptionService+Adaptive.swift
//
// v5 feat/v5-adaptive-scheduling — extends DisruptionService with the empathetic "the day went
// sideways" suggestions: health-aware lightening (a rough night → a lighter day), no-guilt
// rescheduling of missed blocks, and carry-forward-with-context for yesterday's unfinished work.
// All PURE + testable: they produce an in-memory AdaptiveSuggestion and never mutate anything.
import Foundation

extension DisruptionService {

    /// Sleep (in hours) at/below which we gently offer to lighten the day. Mirrors the
    /// IntegrationSnapshot "low rest" band so the messaging matches the rest hint.
    static let lowRestHours = 6.0

    // MARK: - Health-aware lighten

    /// When last night's sleep was rough, offer a lighter day — warmly, with the choice to keep
    /// the plan. Returns nil when sleep is unknown (≤0) or fine (≥ lowRestHours), so it stays
    /// quiet on normal days. `plannedGoalBlocks` lets the copy acknowledge a busy day specifically.
    static func healthLightenSuggestion(sleepHours: Double, plannedGoalBlocks: Int) -> AdaptiveSuggestion? {
        guard sleepHours > 0, sleepHours < lowRestHours else { return nil }
        let hoursText = sleepHours == sleepHours.rounded() ? String(Int(sleepHours)) : String(format: "%.1f", sleepHours)
        let load = plannedGoalBlocks >= 4 ? "a full day planned" : "today's plan"
        return AdaptiveSuggestion(
            kind: .healthLighten,
            title: "Looks like you didn't sleep great",
            body: "About \(hoursText)h last night, and you've got \(load). No need to push — want to make today lighter and let the rest roll forward?",
            symbol: "moon.zzz",
            options: [
                AdaptiveOption(id: "lighten", label: "Make today lighter", isPrimary: true),
                AdaptiveOption(id: "keep", label: "I'm good, keep my plan"),
            ]
        )
    }

    // MARK: - Missed-item reschedule (no guilt)

    /// One missed block to offer a new time for.
    struct MissedItem: Equatable {
        let title: String
        let originalSlot: String
    }

    /// When blocks slipped, propose moving them to a free slot today (or gently to tomorrow when
    /// the day's full) — framed as "that happens", never as failure. Returns nil with no missed
    /// items. `freeSlots` are open "HH:mm" times later today; empty means no room left today.
    static func rescheduleMissedSuggestion(missed: [MissedItem], freeSlots: [String]) -> AdaptiveSuggestion? {
        guard !missed.isEmpty else { return nil }
        let count = missed.count
        let word = count == 1 ? "block" : "blocks"
        let firstTitle = missed.first?.title ?? "it"

        let primaryLabel: String
        if let slot = freeSlots.first {
            primaryLabel = count == 1 ? "Move \"\(firstTitle)\" to \(slot)" : "Fit them back in later today"
        } else {
            primaryLabel = count == 1 ? "Carry \"\(firstTitle)\" to tomorrow" : "Carry them to tomorrow"
        }

        return AdaptiveSuggestion(
            kind: .missedReschedule,
            title: count == 1 ? "One block slipped — that happens" : "\(count) \(word) slipped — that happens",
            body: freeSlots.isEmpty
                ? "The day filled up. We can roll \(count == 1 ? "it" : "them") to tomorrow — nothing's lost."
                : "There's still room later today if you want \(count == 1 ? "it" : "them") to land. Or let \(count == 1 ? "it" : "them") roll forward, no pressure.",
            symbol: "arrow.uturn.forward",
            options: [
                AdaptiveOption(id: "reschedule", label: primaryLabel, isPrimary: true),
                AdaptiveOption(id: "rollforward", label: "Let it roll forward"),
            ]
        )
    }

    // MARK: - Carry-forward with context

    /// One unfinished item carried from a previous day.
    struct CarryItem: Equatable {
        let title: String
        let goalTitle: String?
    }

    /// Ask, with context, whether yesterday's unfinished work still matters — "still important, or
    /// should we let it go?" — instead of silently re-stacking it. Returns nil when nothing's
    /// carried.
    static func carryForwardSuggestion(unfinished: [CarryItem]) -> AdaptiveSuggestion? {
        guard let first = unfinished.first else { return nil }
        let count = unfinished.count
        let context = first.goalTitle.map { " for \($0)" } ?? ""
        let title = count == 1
            ? "You didn't finish \"\(first.title)\" yesterday"
            : "\(count) things rolled over from yesterday"
        let body = count == 1
            ? "Still important\(context), or has it passed? You decide — there's no penalty either way."
            : "Want to bring them forward, or clear the ones that no longer matter? Your call, no guilt."
        return AdaptiveSuggestion(
            kind: .carryForward,
            title: title,
            body: body,
            symbol: "calendar.badge.clock",
            options: [
                AdaptiveOption(id: "reschedule", label: count == 1 ? "Still important — reschedule" : "Bring them forward", isPrimary: true),
                AdaptiveOption(id: "letgo", label: count == 1 ? "Let it go" : "Clear them"),
            ]
        )
    }
}
