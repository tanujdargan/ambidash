import Testing
import Foundation
@testable import ambidash

@Test func pulseScoreIsAverageOfDimensions() {
    let dimScores: [LifeDimension: Int] = [
        .body: 80, .mind: 60, .craft: 70, .people: 40, .wealth: 50, .adventure: 60,
    ]
    let pulse = PulseScoreCalculator.pulse(from: dimScores)
    #expect(pulse == 60)
}

@Test func pulseScoreClampedTo0_100() {
    let low: [LifeDimension: Int] = [
        .body: 0, .mind: 0, .craft: 0, .people: 0, .wealth: 0, .adventure: 0,
    ]
    #expect(PulseScoreCalculator.pulse(from: low) == 0)

    let high: [LifeDimension: Int] = [
        .body: 100, .mind: 100, .craft: 100, .people: 100, .wealth: 100, .adventure: 100,
    ]
    #expect(PulseScoreCalculator.pulse(from: high) == 100)
}
