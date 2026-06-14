import Foundation

// Phase 2 — the domain-module framework. The single internal contract every life area
// implements so the app can get BROADER without becoming 100 bolted-on tools. A domain
// touches the user through EXACTLY these five things and nothing else (Section 5 of the
// plan):
//   1. a score dimension (its 0…100 contribution to the one composite score)
//   2. signals in   — its inputs, normalized into value snapshots (held by the concrete
//                     module at construction, so the protocol stays pure + testable)
//   3. items out    — actionable candidates into the ONE plan, via PlanRanking
//   4. one lens      — at most one optional drill-in route (never a competing tab)
//   5. nudges        — specs registered with the ONE JITAI layer (no per-domain notifs)
//
// If something a domain wants doesn't fit these five, it's trying to be a separate app —
// defer it. This contract is the mechanism that keeps the life-OS cohesive as it grows.

/// A nudge a domain wants the one JITAI layer (JITAINudge + FrequencyCaps) to consider.
/// `category` is the domain id → its frequency-cap bucket.
struct DomainNudge: Equatable {
    let category: String
    let title: String
    let body: String
    /// Optional time-of-day hint (minute-of-day) for the planner/bandit; nil = any time.
    let preferredMinuteOfDay: Int?
}

/// The contract every life domain implements.
protocol DomainModule {
    /// Stable id, e.g. "wealth", "health". Doubles as the nudge frequency-cap category.
    var id: String { get }
    var displayName: String { get }
    /// (1) Which dimension of the one composite score this domain contributes to.
    var dimension: LifeDimension { get }
    /// (4) The one optional lens — a deep-link route, or nil if the domain has no drill-in.
    var lensRoute: String? { get }

    /// (1) 0…100 contribution to the one score. 50 = neutral (no data yet).
    func dimensionScore(now: Date) -> Int
    /// (3) Candidates this domain drops into the one plan.
    func planCandidates(now: Date) -> [PlanRanking.Candidate]
    /// (5) Nudges this domain registers with the one JITAI layer.
    func nudges(now: Date) -> [DomainNudge]
}

extension DomainModule {
    var lensRoute: String? { nil }
    func nudges(now: Date) -> [DomainNudge] { [] }
}

/// Aggregates the active domain modules into the spine's three shared surfaces: the one
/// score, the one plan, and the one nudge layer. Adding a domain = registering a module
/// here; everything rolls up automatically and cohesively.
struct DomainRegistry {
    let modules: [DomainModule]

    /// Each domain's dimension score, keyed by LifeDimension. Last module wins per
    /// dimension (domains should own distinct dimensions).
    func dimensionScores(now: Date = .now) -> [LifeDimension: Int] {
        var out: [LifeDimension: Int] = [:]
        for m in modules { out[m.dimension] = m.dimensionScore(now: now) }
        return out
    }

    /// The one composite score, via the same PulseScoreCalculator the app already uses.
    func compositeScore(now: Date = .now) -> Int {
        PulseScoreCalculator.pulse(from: dimensionScores(now: now))
    }

    /// Every domain's candidates, ranked into one plan order via the one PlanRanking engine.
    func planCandidates(now: Date = .now) -> [PlanRanking.Candidate] {
        PlanRanking.rank(modules.flatMap { $0.planCandidates(now: now) })
    }

    /// Every domain's nudges, for the one JITAI layer to schedule under frequency caps.
    func nudges(now: Date = .now) -> [DomainNudge] {
        modules.flatMap { $0.nudges(now: now) }
    }
}
