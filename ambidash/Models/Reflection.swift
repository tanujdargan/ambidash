import Foundation
import SwiftData

@Model
final class Reflection {
    var id: UUID = UUID()
    var date: Date = Date()
    var typeRaw: String = ""
    var mood: String = ""
    var blockers: [String] = []
    var freeformText: String = ""

    /// CLOSING RITUAL — the user's chosen ONE most-important thing for TOMORROW,
    /// set during the gentle end-of-day flow. The next plan-generation (and the
    /// Now/Next surfaces) read the most recent reflection's value and pin it as the
    /// protected first block. Empty when the user skipped this step.
    /// Additive/defaulted scalar (CloudKit-safe; no container/migration change —
    /// Reflection is already registered in both ModelContainers).
    var tomorrowOneThing: String = ""

    /// CLOSING RITUAL — optional link to an existing planned action chosen as
    /// tomorrow's ONE thing (when the user picks from today's carried-forward work
    /// rather than typing a fresh intent). Plain UUID? (NOT a relationship) to keep
    /// the CloudKit surface additive. nil when the one-thing is free text or unset.
    var tomorrowOneThingActionID: UUID?

    /// PHOTO-OF-NOTES — photos the user attached to this reflection (each carrying its
    /// own on-device-OCR'd text). Cascade-delete so removing a reflection clears its
    /// photos; the inverse lives on the child (`ReflectionPhoto.reflection`). Optional +
    /// defaulted per the CloudKit additive rule — no migration, no container change
    /// beyond registering `ReflectionPhoto` in both ModelContainers.
    @Relationship(deleteRule: .cascade) var photos: [ReflectionPhoto]? = nil

    init(date: Date = .now, type: String = "daily") {
        self.id = UUID()
        self.date = date
        self.typeRaw = type
        self.mood = ""
        self.blockers = []
        self.freeformText = ""
        self.tomorrowOneThing = ""
        self.tomorrowOneThingActionID = nil
    }
}
