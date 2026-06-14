import Foundation
import SwiftData

// Phase 3a — on-device / manual money. Goal-framed finance, NOT a Mint clone: money is a
// scored dimension of the one composite score (via WealthDomainModule), not a spreadsheet.
//
// Privacy: this is all manual / on-device data in the user's own private iCloud (CloudKit),
// the same as Goals/Reflections — it adds ZERO to the App Privacy "Financial Info" label,
// which is reserved for cloud aggregators (Plaid, Phase 3b). CloudKit-safe: every scalar
// defaulted, no required relationships.

/// A money account (manual now; Plaid-linked later in 3b). `source` stays "manual" here.
@Model
final class FinanceAccount {
    var id: UUID = UUID()
    var name: String = ""
    /// checking | savings | credit | cash
    var typeRaw: String = "checking"
    var balance: Double = 0
    /// manual | plaid  — always "manual" in 3a.
    var sourceRaw: String = "manual"
    var createdAt: Date = Date.now

    init(name: String = "", typeRaw: String = "checking", balance: Double = 0, sourceRaw: String = "manual") {
        self.id = UUID()
        self.name = name
        self.typeRaw = typeRaw
        self.balance = balance
        self.sourceRaw = sourceRaw
        self.createdAt = .now
    }
}

/// One logged transaction. `amount` is positive for a spend, by convention; income uses a
/// negative spend. Category strings are user-defined, matched to BudgetCategory by name.
@Model
final class FinanceTransaction {
    var id: UUID = UUID()
    /// Spend amount (positive). Income/refund can be logged as a negative spend.
    var amount: Double = 0
    var category: String = ""
    var note: String = ""
    var date: Date = Date.now
    /// manual | ocr | plaid — how it was captured.
    var sourceRaw: String = "manual"

    init(amount: Double = 0, category: String = "", note: String = "", date: Date = .now, sourceRaw: String = "manual") {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.sourceRaw = sourceRaw
    }
}

/// A non-punitive spending budget: a cap per period, optionally percentile-adaptive
/// ("right-sized for this month", never "you failed your budget").
@Model
final class BudgetCategory {
    var id: UUID = UUID()
    var name: String = ""
    /// The spend cap for the period.
    var cap: Double = 0
    /// week | month
    var periodRaw: String = "month"
    /// When true, the cap is re-sized from recent spending percentiles rather than fixed.
    var adaptive: Bool = false
    var createdAt: Date = Date.now

    init(name: String = "", cap: Double = 0, periodRaw: String = "month", adaptive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.cap = cap
        self.periodRaw = periodRaw
        self.adaptive = adaptive
        self.createdAt = .now
    }
}
