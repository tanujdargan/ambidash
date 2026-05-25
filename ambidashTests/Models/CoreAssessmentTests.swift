import Testing
import Foundation
@testable import ambidash

@Test func coreAssessmentInitializesWithDefaults() {
    let assessment = CoreAssessment()
    #expect(assessment.adhdScore == 0)
    #expect(assessment.topValues.isEmpty)
    #expect(assessment.cognitiveStyle == "")
}
