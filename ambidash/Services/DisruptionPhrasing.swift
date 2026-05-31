// ambidash/Services/DisruptionPhrasing.swift
//
// Gentle, on-device phrasing for the mid-day disruption re-plan. The DisruptionService
// already produces a fully usable, deterministic WHY line for every entry — this layer
// only WARMS the top-level rationale (the one humane sentence the user reads first),
// walking the same privacy-first fallback chain as CaptureDecomposeService:
//
//   1. ON-DEVICE Apple Foundation Models (iOS 26, availability-gated) — energy/health
//      context NEVER leaves the device.
//   2. EXISTING AIService BYOK (Claude) — only if a key is configured and on-device is
//      unavailable. Reuses the single networking layer; no second one.
//   3. The deterministic `trigger.rationale` from DisruptionService — always works,
//      zero cost, no model. This is the floor; the diff is fully usable with no model.
//
// Only AGGREGATE / non-identifying context is ever sent off-device (the BYOK tier):
// counts of moved/dropped + the protected title — never goal details, reflections, or
// the energy number. The on-device tier may use richer context since it stays local.

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum DisruptionPhrasing {

    /// Warm the top-line rationale for a proposed re-plan. Returns a single calm
    /// sentence. Never throws — the worst case is the deterministic rationale.
    static func rationale(for diff: DisruptionService.PlanDiff) async -> String {
        let fallback = diff.rationale
        let protectedTitle = diff.protectedEntry?.title ?? ""

        if let onDevice = await onDevice(
            trigger: diff.trigger,
            moved: diff.movedCount,
            dropped: diff.droppedCount,
            protectedTitle: protectedTitle,
            fallback: fallback
        ) {
            return onDevice
        }
        if let byok = await byok(
            trigger: diff.trigger,
            moved: diff.movedCount,
            dropped: diff.droppedCount,
            protectedTitle: protectedTitle
        ) {
            return byok
        }
        return fallback
    }

    // MARK: - Tier 1: on-device Foundation Models (iOS 26)

    private static func onDevice(
        trigger: DisruptionService.Trigger,
        moved: Int,
        dropped: Int,
        protectedTitle: String,
        fallback: String
    ) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession {
                """
                You write ONE short, warm, non-punitive sentence for a calm personal \
                dashboard when the user's day has been disrupted. Never blame, never \
                imply failure or laziness. Reassure that nothing is lost — deferred \
                work rolls forward. Protect the user's one most-important thing. Keep \
                it under 22 words. No emoji. No exclamation marks.
                """
            }
            let situation = situationLine(
                trigger: trigger, moved: moved, dropped: dropped, protectedTitle: protectedTitle
            )
            let response = try await session.respond(to: situation)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Tier 2: BYOK (existing AIService networking)

    @MainActor
    private static func byok(
        trigger: DisruptionService.Trigger,
        moved: Int,
        dropped: Int,
        protectedTitle: String
    ) async -> String? {
        guard AIConfig.isConfigured else { return nil }
        let situation = situationLine(
            trigger: trigger, moved: moved, dropped: dropped, protectedTitle: protectedTitle
        )
        let prompt = """
        You write ONE short, warm, non-punitive sentence for a calm personal dashboard \
        when the user's day has been disrupted. Never blame or imply failure. Reassure \
        that nothing is lost — deferred work rolls forward. Under 22 words. No emoji, \
        no exclamation marks. Reply with ONLY the sentence.

        Situation: \(situation)
        """
        do {
            let raw = try await AIService.rawCompletion(prompt: prompt)
            let line = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            return (line?.isEmpty == false) ? line : nil
        } catch {
            return nil
        }
    }

    // MARK: - Shared situation framing (aggregates only)

    /// A compact, NON-identifying description of the re-plan for the model. Carries
    /// only counts + the protected title — never the energy number, goal details, or
    /// any reflection text.
    private static func situationLine(
        trigger: DisruptionService.Trigger,
        moved: Int,
        dropped: Int,
        protectedTitle: String
    ) -> String {
        var parts: [String] = []
        switch trigger {
        case .manual:          parts.append("The user said their day changed.")
        case .lowEnergy:       parts.append("The user is low on energy.")
        case .missedBlocks:    parts.append("A few planned blocks slipped.")
        case .calendarOverrun: parts.append("Something ran long and ate their free time.")
        case .healthFlare:     parts.append("The user needs to prioritize their health and rest.")
        }
        if moved > 0 { parts.append("\(moved) task\(moved == 1 ? "" : "s") moved later.") }
        if dropped > 0 { parts.append("\(dropped) task\(dropped == 1 ? "" : "s") roll forward to tomorrow.") }
        if !protectedTitle.isEmpty { parts.append("Protecting: \(protectedTitle).") }
        return parts.joined(separator: " ")
    }
}
