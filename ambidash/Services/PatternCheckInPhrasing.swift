// ambidash/Services/PatternCheckInPhrasing.swift
//
// Gentle, on-device phrasing for a pattern check-in (build-order #8). The
// PatternCheckInService already produces a fully usable, deterministic body line for
// every insight — this layer only WARMS that one sentence the user reads, walking the
// same privacy-first fallback chain as DisruptionPhrasing / CaptureDecomposeService:
//
//   1. ON-DEVICE Apple Foundation Models (iOS 26, availability-gated) — wake/sleep /
//      adherence context NEVER leaves the device.
//   2. EXISTING AIService BYOK (Claude) — only if a key is configured and on-device is
//      unavailable. Reuses the single networking layer; no second one.
//   3. The deterministic `insight.body` from PatternCheckInService — always works,
//      zero cost, no model. The floor; the card is fully usable with no model at all.
//
// Only AGGREGATE / non-identifying context is ever sent off-device (the BYOK tier):
// the drift KIND + the two choice labels — never goal details, reflections, or raw
// logged events. The on-device tier may use the (still aggregate) body directly.
//
// CONTRACT: the warmed copy must stay an OFFER, never a verdict — no blame, no "you
// failed", no red. The instructions enforce that; on any doubt we keep the
// deterministic copy.

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum PatternCheckInPhrasing {

    /// Warm the body line of a pattern check-in. Returns a single calm, non-judgmental
    /// sentence. Never throws — the worst case is the deterministic `insight.body`.
    static func body(for insight: PatternCheckInService.PatternInsight) async -> String {
        let fallback = insight.body

        if let onDevice = await onDevice(insight: insight, fallback: fallback) {
            return onDevice
        }
        if let byok = await byok(insight: insight) {
            return byok
        }
        return fallback
    }

    // MARK: - Tier 1: on-device Foundation Models (iOS 26)

    private static func onDevice(
        insight: PatternCheckInService.PatternInsight,
        fallback: String
    ) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession {
                """
                You rewrite ONE short, warm observation for a calm personal dashboard \
                that noticed a gentle pattern in how the user's days actually go. It is \
                an OFFER, never a verdict: never blame, never imply failure, laziness, \
                or that something is wrong with the user. Frame any gap as a scheduling \
                fit, not a personal flaw. Keep the user in control — they choose. Under \
                28 words. No emoji. No exclamation marks.
                """
            }
            let situation = situationLine(insight)
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
        insight: PatternCheckInService.PatternInsight
    ) async -> String? {
        guard AIConfig.isConfigured else { return nil }
        let situation = situationLine(insight)
        let prompt = """
        You rewrite ONE short, warm observation for a calm personal dashboard that \
        noticed a gentle pattern in how the user's days actually go. It is an OFFER, \
        never a verdict: never blame or imply failure or laziness. Frame any gap as a \
        scheduling fit, not a personal flaw. Under 28 words. No emoji, no exclamation \
        marks. Reply with ONLY the sentence.

        Observation: \(situation)
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

    /// A compact, NON-identifying description of the pattern for the model. Reuses the
    /// already-aggregate deterministic body (which holds no raw personal text), plus
    /// the two humane choice labels so the rewrite stays consistent with the buttons.
    private static func situationLine(_ insight: PatternCheckInService.PatternInsight) -> String {
        let choices = insight.choices.map(\.label).joined(separator: " / ")
        return "\(insight.body) (\(insight.confidence)) Choices offered: \(choices)."
    }
}
