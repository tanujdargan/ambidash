import Foundation

// Phase 1 (cohesion spine #4 — one planning engine) — the single ranking every domain's
// candidate actions pass through before landing in the daily plan. The plan specifies:
// deadlineUrgency + priority + goalLinkage + staleness, placed into energy bands (never
// heavy work silently into protected/low-energy time). Pure + testable; the scheduler
// consumes the ordering.
enum PlanRanking {

    /// A domain-agnostic candidate to be ranked into the plan. Any domain (goals, finance,
    /// health, …) maps its actionable item to this shape.
    struct Candidate: Equatable {
        let id: UUID
        /// 1 = highest priority. Clamped 1…10.
        let priority: Int
        /// Days until a hard deadline; nil = no deadline. Negative = overdue.
        let daysUntilDeadline: Int?
        /// Whether this item is tied to an active goal (goalLinkage signal).
        let hasGoalLink: Bool
        /// Days since the item / its goal last saw progress (staleness signal).
        let daysSinceProgress: Int
        /// 1…5 cognitive load, used only for energy-band placement (not the score).
        let cognitiveLoad: Int
    }

    enum EnergyBand: String, Equatable { case peak, steady, low }

    /// Composite 0…1 score. Higher = should land sooner / in a richer band.
    static func score(_ c: Candidate) -> Double {
        let deadlineUrgency: Double = {
            guard let d = c.daysUntilDeadline else { return 0 }
            if d <= 0 { return 1 }                       // due/overdue → max urgency
            return max(0, 1 - Double(d) / 14.0)          // ramps over the next two weeks
        }()
        let p = Double(min(max(c.priority, 1), 10))
        let priorityScore = 1 - (p - 1) / 9              // p1 → 1.0, p10 → 0.0
        let goalLinkage = c.hasGoalLink ? 1.0 : 0.0
        let staleness = min(1, Double(max(0, c.daysSinceProgress)) / 7.0)
        return deadlineUrgency * 0.40 + priorityScore * 0.30 + goalLinkage * 0.15 + staleness * 0.15
    }

    /// Rank high → low, with a deterministic tie-break (priority, then id) so the same
    /// inputs always yield the same plan order.
    static func rank(_ candidates: [Candidate]) -> [Candidate] {
        candidates.sorted { a, b in
            let sa = score(a), sb = score(b)
            if sa != sb { return sa > sb }
            if a.priority != b.priority { return a.priority < b.priority }
            return a.id.uuidString < b.id.uuidString
        }
    }

    /// The energy band heavy/light work belongs in — heavy (high cognitive load) only in
    /// peak bands, never silently dropped into low-energy/protected time.
    static func band(forCognitiveLoad load: Int) -> EnergyBand {
        switch load {
        case 4...: return .peak
        case 2...3: return .steady
        default: return .low
        }
    }
}
