import Foundation
import SwiftData

@Model
final class Reflection {
    var id: UUID
    var date: Date
    var typeRaw: String
    var mood: String
    var blockers: [String]
    var freeformText: String

    init(date: Date = .now, type: String = "daily") {
        self.id = UUID()
        self.date = date
        self.typeRaw = type
        self.mood = ""
        self.blockers = []
        self.freeformText = ""
    }
}
