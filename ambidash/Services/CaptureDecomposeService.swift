import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Suggests a gentle triage for a captured thought, with a strict, privacy-first
/// fallback chain (design principle #4 + #9, iOS-26 cheat-sheet §3):
///
///   1. ON-DEVICE Apple Foundation Models (iOS 26, availability-gated) — the thought
///      never leaves the device. `@Generable` structured output → a suggested kind
///      (task/goal/note) + a short, calm restatement + an optional duration.
///   2. EXISTING AIService BYOK (Claude) — only if the user has configured a key and
///      on-device is unavailable. Reuses the single networking layer (no second one).
///   3. PLAIN local heuristic (`CaptureService.heuristicGuess`) — always works, zero
///      cost, no network, no model. This is the MVP floor: triage is fully usable
///      with NO model at all.
///
/// All paths return the same `Suggestion`, so the triage UI is identical regardless
/// of which tier produced it. Failures degrade silently to the next tier — a
/// suggestion is a convenience, never a gate.
enum CaptureDecomposeService {

    /// A non-authoritative triage suggestion for one captured thought.
    struct Suggestion: Equatable {
        var kind: CaptureKindGuess
        /// A short, calm restatement to use as the promoted Goal/task title. Falls
        /// back to the raw text when a model isn't available.
        var refinedTitle: String
        /// Estimated minutes if it reads like a task; nil otherwise.
        var durationMinutes: Int?
        /// Which tier produced this (for a quiet "on-device" / "manual" affordance).
        var origin: Origin

        enum Origin: String { case onDevice, byok, heuristic }

        var suggestedAction: CaptureTriageAction { kind.suggestedTriage }
    }

    /// Resolve a suggestion for `text`, walking the fallback chain. Never throws —
    /// the worst case is the heuristic tier, which always succeeds.
    static func suggest(for text: String) async -> Suggestion {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Suggestion(kind: .unknown, refinedTitle: trimmed, durationMinutes: nil, origin: .heuristic)
        }

        if let onDevice = await onDeviceSuggestion(for: trimmed) {
            return onDevice
        }
        if let byok = await byokSuggestion(for: trimmed) {
            return byok
        }
        return heuristicSuggestion(for: trimmed)
    }

    // MARK: - Tier 3: heuristic (always available)

    static func heuristicSuggestion(for text: String) -> Suggestion {
        let kind = CaptureService.heuristicGuess(for: text)
        return Suggestion(kind: kind, refinedTitle: text, durationMinutes: nil, origin: .heuristic)
    }

    // MARK: - Tier 1: on-device Foundation Models (iOS 26)

    private static func onDeviceSuggestion(for text: String) async -> Suggestion? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession {
                """
                You gently triage a single captured thought for a calm, non-punitive \
                personal dashboard. Classify it as a task (a small doable action), a \
                goal (a longer-range aspiration), or a note (an idea with no clear \
                action). Give a short, kind restatement suitable as a title. If it is \
                a task, estimate minutes. Never invent urgency. Keep it brief.
                """
            }
            // The untrusted captured text goes in the PROMPT, never the instructions.
            let response = try await session.respond(
                to: "Thought: \(text)",
                generating: GeneratedTriage.self
            )
            let g = response.content
            let kind = CaptureKindGuess(rawValue: g.kind.lowercased()) ?? .unknown
            let title = g.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Suggestion(
                kind: kind == .unknown ? CaptureService.heuristicGuess(for: text) : kind,
                refinedTitle: title.isEmpty ? text : title,
                durationMinutes: g.durationMinutes.flatMap { $0 > 0 ? $0 : nil },
                origin: .onDevice
            )
        } catch {
            // exceededContextWindow / guardrailViolation / assetsUnavailable / etc. →
            // degrade silently to the next tier.
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Tier 2: BYOK (existing AIService networking)

    private static func byokSuggestion(for text: String) async -> Suggestion? {
        guard AIConfig.isConfigured else { return nil }
        do {
            let raw = try await AIService.triageCaptureJSON(text: text)
            guard let data = sliceJSON(raw)?.data(using: .utf8) else { return nil }
            let decoded = try JSONDecoder().decode(ByokTriage.self, from: data)
            let kind = CaptureKindGuess(rawValue: decoded.kind.lowercased()) ?? .unknown
            let title = decoded.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Suggestion(
                kind: kind == .unknown ? CaptureService.heuristicGuess(for: text) : kind,
                refinedTitle: title.isEmpty ? text : title,
                durationMinutes: decoded.durationMinutes.flatMap { $0 > 0 ? $0 : nil },
                origin: .byok
            )
        } catch {
            return nil
        }
    }

    /// Extract the first `{...}` object from a model reply that may include prose.
    private static func sliceJSON(_ s: String) -> String? {
        guard let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}"), open < close else { return nil }
        return String(s[open...close])
    }

    private struct ByokTriage: Decodable {
        let kind: String
        let title: String
        let durationMinutes: Int?
    }
}

// MARK: - On-device generable schema (iOS 26)

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct GeneratedTriage {
    @Guide(description: "One of: task, goal, note")
    var kind: String
    @Guide(description: "A short, calm restatement usable as a title")
    var title: String
    @Guide(description: "Estimated minutes if it is a task, else 0")
    var durationMinutes: Int?
}
#endif
