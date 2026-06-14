import Testing
import Foundation
@testable import ambidash

// Phase 3a — pure money logic: quick-spend parsing, non-punitive budget status, the
// Minimum Viable Floor, percentile-adaptive caps, and the bridge that turns budgets into
// WealthDomainModule snapshots (money → the one score).

private typealias F = FinanceLogic
private let cal = Calendar(identifier: .gregorian)
private func at(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

// MARK: - Quick-spend parse

@Test func parseQuickSpendExtractsAmountAndCategory() {
    #expect(F.parseQuickSpend("spent $12.50 on coffee")?.amount == 12.5)
    #expect(F.parseQuickSpend("spent $12.50 on coffee")?.category == "coffee")
    #expect(F.parseQuickSpend("15 groceries")?.amount == 15)
    #expect(F.parseQuickSpend("15 groceries")?.category == "groceries")
    #expect(F.parseQuickSpend("paid $4 for parking")?.category == "parking")
    #expect(F.parseQuickSpend("$1,200 on rent")?.amount == 1200)
    #expect(F.parseQuickSpend("no number here") == nil)
}

// MARK: - Spending + non-punitive status

@Test func spentSumsCategoryWithinInterval() {
    let txns = [
        F.TxnSnapshot(amount: 10, category: "food", date: at(2026, 6, 5)),
        F.TxnSnapshot(amount: 20, category: "food", date: at(2026, 6, 10)),
        F.TxnSnapshot(amount: 99, category: "rent", date: at(2026, 6, 6)),   // other category
        F.TxnSnapshot(amount: 50, category: "food", date: at(2026, 5, 1)),   // outside interval
    ]
    let june = DateInterval(start: at(2026, 6, 1), end: at(2026, 6, 30))
    #expect(F.spent(txns, category: "food", in: june) == 30)
}

@Test func budgetStatusIsNonPunitive() {
    #expect(F.status(spent: 70, cap: 100) == .onTrack)
    #expect(F.status(spent: 90, cap: 100) == .watch)
    #expect(F.status(spent: 130, cap: 100) == .scheduled)   // never "over" — carried forward
    #expect(F.status(spent: 999, cap: 0) == .onTrack)        // no cap → no judgment
    #expect(F.remaining(spent: 130, cap: 100) == -30)        // negative is fine (carried)
}

@Test func minimumViableFloorCountsTinyWins() {
    #expect(F.meetsFloor(5) == true)
    #expect(F.meetsFloor(2) == false)
    #expect(F.meetsFloor(10, floor: 20) == false)
}

@Test func adaptiveCapIsPercentileOfRecentSpend() {
    // 75th percentile of [100,200,300,400] = 325 (linear interpolation).
    #expect(F.adaptiveCap(recentPeriodSpends: [400, 100, 300, 200], fallback: 0) == 325)
    #expect(F.adaptiveCap(recentPeriodSpends: [], fallback: 250) == 250)   // fallback when no history
}

// MARK: - Bridge to the one score

@Test func wealthSnapshotsRewardStayingUnderBudget() {
    let budgets = [
        F.BudgetSnapshot(name: "food", cap: 100, period: .month),
        F.BudgetSnapshot(name: "fun", cap: 200, period: .month),
    ]
    let snaps = F.wealthSnapshots(budgets: budgets, spentByName: ["food": 20, "fun": 200])
    let food = snaps.first { $0.title == "food" }
    let fun = snaps.first { $0.title == "fun" }
    #expect(food?.percentComplete == 0.8)   // $20 of $100 → 80% room left = doing well
    #expect(fun?.percentComplete == 0.0)     // spent the whole cap → 0 room

    // And those snapshots drive the wealth dimension of the one score (Phase 2 → 3).
    let module = WealthDomainModule(goals: snaps)
    #expect(module.dimensionScore(now: .now) == 40)   // avg(0.8, 0.0) = 0.4 → 40
}
