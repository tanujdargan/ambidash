import Testing
import Foundation
@testable import ambidash

@Test func pulseScoreIsAverageOfDimensions() {
    let dimScores: [LifeDimension: Int] = [
        .body: 80, .mind: 60, .focus: 70, .social: 40, .growth: 50,
    ]
    let pulse = PulseScoreCalculator.pulse(from: dimScores)
    #expect(pulse == 60)
}

@Test func pulseScoreClampedTo0_100() {
    let low: [LifeDimension: Int] = [
        .body: 0, .mind: 0, .focus: 0, .social: 0, .growth: 0,
    ]
    #expect(PulseScoreCalculator.pulse(from: low) == 0)

    let high: [LifeDimension: Int] = [
        .body: 100, .mind: 100, .focus: 100, .social: 100, .growth: 100,
    ]
    #expect(PulseScoreCalculator.pulse(from: high) == 100)
}
