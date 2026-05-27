import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightService {
    static func indexGoals(_ goals: [Goal]) {
        let items = goals.map { goal -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: UTType.text)
            attributes.title = goal.title
            attributes.contentDescription = goal.subtitle.isEmpty ? goal.domain.displayName : goal.subtitle
            attributes.keywords = [goal.domain.displayName, goal.horizon.displayName, "goal", "ambidash"]

            return CSSearchableItem(
                uniqueIdentifier: "goal-\(goal.id.uuidString)",
                domainIdentifier: "com.ambidash.goals",
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items)
    }

    static func removeAllGoals() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.ambidash.goals"])
    }
}
