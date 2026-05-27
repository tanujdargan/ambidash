import Testing
import Foundation
@testable import ambidash

@Test func goalLibraryReturnsGoalsForAllDomains() {
    for domain in GoalDomain.allCases {
        let goals = GoalLibrary.starterGoals(for: domain)
        #expect(!goals.isEmpty, "GoalLibrary should return goals for \(domain.displayName)")
        #expect(goals.allSatisfy { !$0.title.isEmpty }, "All goals should have titles for \(domain.displayName)")
    }
}

@Test func goalLibraryHorizonsAreValid() {
    for domain in GoalDomain.allCases {
        let goals = GoalLibrary.starterGoals(for: domain)
        for goal in goals {
            #expect(GoalHorizon.allCases.contains(goal.horizon), "Horizon should be valid for \(goal.title)")
        }
    }
}

@Test func allAssessmentQuestionsHaveOptions() {
    let questions = CoreAssessmentQuestions.all
    #expect(questions.count >= 8, "Should have at least 8 assessment questions")
    for q in questions {
        #expect(!q.options.isEmpty, "Question '\(q.text)' should have options")
        #expect(!q.id.isEmpty, "Question should have an id")
        #expect(!q.text.isEmpty, "Question should have text")
    }
}

@Test func domainAssessmentQuestionsExistForAllDomains() {
    for domain in GoalDomain.allCases {
        let questions = DomainAssessmentQuestions.questions(for: domain)
        #expect(!questions.isEmpty, "Should have domain questions for \(domain.displayName)")
        for q in questions {
            #expect(!q.options.isEmpty, "Domain question '\(q.text)' should have options")
        }
    }
}

@Test func themeManagerDefaultsToYellowDark() {
    let tm = ThemeManager()
    #expect(tm.palette == .yellow)
    #expect(tm.isDark == true)
    #expect(tm.typography == .technical)
    #expect(tm.density == .detailed)
}

@Test func themeResolvedColorsExist() {
    let tm = ThemeManager()
    let t = tm.resolved
    #expect(t.isDark == true)
}

@Test func goalHorizonHasCorrectTimeframes() {
    #expect(GoalHorizon.now.timeframe == "0–3 months")
    #expect(GoalHorizon.soon.timeframe == "3–12 months")
    #expect(GoalHorizon.build.timeframe == "1–3 years")
    #expect(GoalHorizon.dream.timeframe == "3–10 years")
}

@Test func goalModelSupportsHorizonAndSubtitle() {
    let goal = Goal(title: "Test", domain: .body, priority: 1)
    goal.subtitle = "test subtitle"
    goal.horizon = .dream
    #expect(goal.subtitle == "test subtitle")
    #expect(goal.horizon == .dream)
    #expect(goal.horizonRaw == "dream")
}

@Test func scaffoldingServiceRecommendsHeavyForNewUsers() {
    let profile = UserProfile(name: "Test", age: 21)
    let level = ScaffoldingService.recommendedLevel(for: profile)
    #expect(level == .heavy)
}

@Test func skipAnalysisHandlesEmptyPlans() {
    let result = SkipAnalysisService.analyze(plans: [], goals: [])
    #expect(result.overallSkipRate == 0)
    #expect(result.patterns.isEmpty)
    #expect(result.recommendation == "Not enough data yet.")
}

@Test func streakServiceSummaryHandlesNoGoals() {
    let summary = StreakService.summary(for: [])
    #expect(summary.totalActiveStreaks == 0)
    #expect(summary.longestCurrentStreak == 0)
    #expect(summary.atRiskStreaks.isEmpty)
}

@Test func dataExportProducesValidJSON() {
    let profile = UserProfile(name: "Test", age: 21)
    let data = DataExportService.exportJSON(profile: profile, plans: [], reflections: [], snapshots: [])
    #expect(data != nil)
    if let d = data {
        let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        #expect(json != nil)
        #expect(json?["app_version"] as? String == "1.0.0")
    }
}

@Test func goalProgressTrackerReturnsScores() {
    let goal = Goal(title: "Test", domain: .body, priority: 1)
    let scores = GoalProgressTracker.recentScores(for: goal, days: 7)
    #expect(scores.isEmpty)
}
