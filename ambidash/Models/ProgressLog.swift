import Foundation
import SwiftData

@Model
final class ProgressLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Double = 0
    var resultingValue: Double = 0
    var note: String = ""
    var sourceRaw: String = ProgressLogSource.manual.rawValue

    var goal: Goal?

    init(amount: Double, resultingValue: Double, note: String = "", source: ProgressLogSource = .manual) {
        self.id = UUID()
        self.date = .now
        self.amount = amount
        self.resultingValue = resultingValue
        self.note = note
        self.sourceRaw = source.rawValue
    }

    var source: ProgressLogSource {
        get { ProgressLogSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
