import Foundation

// Phase 3a — the PURE money logic. Non-punitive throughout (the ND doctrine applied to
// finance, where users feel the most shame): no red "over budget", a Minimum Viable Floor
// so "move $5" counts, percentile-adaptive caps ("right-sized for this month"). Operates on
// value snapshots so it's fully testable; the views/models feed it. Also bridges finance →
// the Phase-2 WealthDomainModule so money becomes a dimension of the one score.
enum FinanceLogic {

    struct TxnSnapshot: Equatable { let amount: Double; let category: String; let date: Date }
    enum BudgetPeriod: String, Equatable { case week, month }
    struct BudgetSnapshot: Equatable { let name: String; let cap: Double; let period: BudgetPeriod }

    /// Non-punitive budget state — never "over". A breach is reframed as "carried forward".
    enum BudgetStatus: String, Equatable { case onTrack, watch, scheduled }

    // MARK: - Quick capture ("spent $12.50 on coffee")

    /// Parse a one-line spend capture into (amount, category). Forgiving: finds the first
    /// number (with/without `$`/commas), and the category after "on"/"for" or the leftover
    /// words. Returns nil when there's no number to log.
    static func parseQuickSpend(_ text: String) -> (amount: Double, category: String)? {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        var amount: Double?
        var amountIdx = -1
        for (i, w) in words.enumerated() where amount == nil {
            let cleaned = w.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            if let v = Double(cleaned) { amount = v; amountIdx = i }
        }
        guard let amt = amount else { return nil }
        let lower = words.map { $0.lowercased() }
        if let onIdx = lower.firstIndex(where: { $0 == "on" || $0 == "for" }), onIdx + 1 < words.count {
            return (amt, words[(onIdx + 1)...].joined(separator: " "))
        }
        let filler: Set<String> = ["spent", "spend", "paid", "bought", "a", "an", "the"]
        let cat = words.enumerated()
            .filter { $0.offset != amountIdx && !filler.contains($0.element.lowercased()) }
            .map(\.element).joined(separator: " ")
        return (amt, cat.isEmpty ? "uncategorized" : cat)
    }

    // MARK: - Spending / budget

    /// Total spent in a category within an interval (income — negative amounts — nets out).
    static func spent(_ txns: [TxnSnapshot], category: String, in interval: DateInterval) -> Double {
        txns.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame
                      && interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Non-punitive status from spend vs cap. < 80% → on track; < 100% → watch; ≥ 100% →
    /// "scheduled" (the overage rolls into next period — never a failure). cap ≤ 0 → onTrack.
    static func status(spent: Double, cap: Double) -> BudgetStatus {
        guard cap > 0 else { return .onTrack }
        let ratio = spent / cap
        if ratio < 0.8 { return .onTrack }
        if ratio < 1.0 { return .watch }
        return .scheduled
    }

    /// Remaining budget. Negative is fine — framed as the amount "carried forward".
    static func remaining(spent: Double, cap: Double) -> Double { cap - spent }

    /// A tiny contribution still counts on a low-spoons day (Minimum Viable Floor).
    static func meetsFloor(_ amount: Double, floor: Double = 5) -> Bool { amount >= floor }

    /// Percentile-adaptive cap from recent per-period spends (default 75th percentile),
    /// so a budget is "right-sized" to reality rather than an aspirational fail-trap.
    static func adaptiveCap(recentPeriodSpends: [Double], fallback: Double, percentile: Double = 0.75) -> Double {
        let sorted = recentPeriodSpends.filter { $0 >= 0 }.sorted()
        guard !sorted.isEmpty else { return fallback }
        let rank = min(max(percentile, 0), 1) * Double(sorted.count - 1)
        let lo = Int(rank.rounded(.down)), hi = Int(rank.rounded(.up))
        let frac = rank - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * frac
    }

    // MARK: - Bridge to the one score (Phase 2 WealthDomainModule)

    /// Turn budgets + their spend into WealthDomainModule snapshots: a budget kept well under
    /// its cap reads as high "progress" on the wealth dimension. `spentByName` is the spend
    /// for each budget this period.
    static func wealthSnapshots(budgets: [BudgetSnapshot], spentByName: [String: Double]) -> [WealthDomainModule.MoneyGoalSnapshot] {
        budgets.map { b in
            let s = spentByName[b.name] ?? 0
            let progress = b.cap > 0 ? max(0, min(1, 1 - s / b.cap)) : 0.5   // room left = doing well
            return WealthDomainModule.MoneyGoalSnapshot(
                title: b.name, percentComplete: progress,
                daysUntilDeadline: nil, priority: 5, daysSinceProgress: 0
            )
        }
    }
}
