import Foundation
import SwiftData

@Model
final class MentorFeedback {
    var id: UUID = UUID()
    var role: String = ""
    var content: String = ""
    var trigger: String = ""
    var createdAt: Date = Date()
    var quotaCost: Int = 0

    init(role: String, content: String, trigger: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.trigger = trigger
        self.createdAt = .now
        self.quotaCost = 1
    }
}
