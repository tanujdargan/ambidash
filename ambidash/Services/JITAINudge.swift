import Foundation

// Phase 1 (cohesion spine #5 — one JITAI layer) — a Thompson-sampling contextual bandit
// that learns WHICH nudge / time-bucket actually earns engagement, plus frequency caps
// with a real "do nothing" arm. One nudge regime serves every domain, so adding finance
// later doesn't bolt on a second nagging notification system.
//
// The bandit is seeded through an injectable RandomNumberGenerator so selection is fully
// deterministic in tests.
enum JITAINudge {

    /// One arm's Beta(α, β) posterior over "this nudge gets engaged". Both start at 1 (a
    /// uniform prior); a success bumps α, an ignore bumps β.
    struct Arm: Equatable {
        var alpha: Double = 1
        var beta: Double = 1

        /// Posterior mean engagement probability — handy for display / greedy fallback.
        var mean: Double { alpha / (alpha + beta) }

        mutating func reward(success: Bool) { if success { alpha += 1 } else { beta += 1 } }
    }

    /// Draw θ ~ Beta(α, β) via two Gamma draws from a uniform RNG. Deterministic under a
    /// seeded generator.
    static func sampleBeta<G: RandomNumberGenerator>(_ arm: Arm, using rng: inout G) -> Double {
        let x = gamma(shape: arm.alpha, using: &rng)
        let y = gamma(shape: arm.beta, using: &rng)
        let sum = x + y
        return sum > 0 ? x / sum : 0.5
    }

    /// Gamma(shape = integer n ≥ 1, scale = 1) = sum of n Exp(1) = -Σ ln(U). α/β are
    /// integer counts in practice, so this is exact (and cheap).
    private static func gamma<G: RandomNumberGenerator>(shape: Double, using rng: inout G) -> Double {
        let n = max(1, Int(shape.rounded()))
        var sum = 0.0
        for _ in 0..<n {
            let u = Double.random(in: Double.leastNonzeroMagnitude...1, using: &rng)
            sum += -Foundation.log(u)
        }
        return sum
    }

    /// Thompson selection: sample each arm's Beta, return the index of the largest sample.
    /// Empty arms → 0.
    static func select<G: RandomNumberGenerator>(_ arms: [Arm], using rng: inout G) -> Int {
        guard !arms.isEmpty else { return 0 }
        var bestIdx = 0
        var bestSample = -1.0
        for (i, arm) in arms.enumerated() {
            let s = sampleBeta(arm, using: &rng)
            if s > bestSample { bestSample = s; bestIdx = i }
        }
        return bestIdx
    }
}

/// Per-day and per-category nudge caps with a real "do nothing" outcome — so the JITAI
/// layer can never nag. Pure: callers pass the recent fire log.
struct FrequencyCaps: Equatable {
    var perDay: Int = 4
    var perCategoryPerDay: Int = 2

    /// Whether a nudge in `category` may fire now given timestamps of recent fires today.
    func canFire(category: String,
                 recentFires: [(category: String, at: Date)],
                 now: Date = .now,
                 calendar: Calendar = .current) -> Bool {
        let today = recentFires.filter { calendar.isDate($0.at, inSameDayAs: now) }
        if today.count >= perDay { return false }
        if today.filter({ $0.category == category }).count >= perCategoryPerDay { return false }
        return true
    }
}
