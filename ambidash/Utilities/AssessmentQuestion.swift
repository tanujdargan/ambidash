// ambidash/Utilities/AssessmentQuestion.swift
import Foundation

struct AssessmentQuestion: Identifiable {
    let id: String
    let text: String
    let subtitle: String
    let options: [AssessmentOption]
    let category: String
    let multiSelect: Bool

    init(
        id: String,
        text: String,
        subtitle: String = "",
        options: [AssessmentOption],
        category: String,
        multiSelect: Bool = false
    ) {
        self.id = id
        self.text = text
        self.subtitle = subtitle
        self.options = options
        self.category = category
        self.multiSelect = multiSelect
    }
}

struct AssessmentOption: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String

    init(id: String, label: String, description: String = "") {
        self.id = id
        self.label = label
        self.description = description
    }
}

enum CoreAssessmentQuestions {
    static let all: [AssessmentQuestion] = [
        // Cognitive & Work Style
        AssessmentQuestion(
            id: "focus_style",
            text: "How do you focus best?",
            subtitle: "There's no wrong answer — this helps us plan your day",
            options: [
                AssessmentOption(id: "deep_blocks", label: "Deep blocks", description: "Long uninterrupted sessions"),
                AssessmentOption(id: "pomodoro", label: "Pomodoro", description: "Timed bursts with breaks"),
                AssessmentOption(id: "task_switching", label: "Task switching", description: "Jumping between tasks keeps you fresh"),
                AssessmentOption(id: "flow_state", label: "Flow state", description: "You can't predict it, but when it hits, you ride it"),
            ],
            category: "cognitive"
        ),
        AssessmentQuestion(
            id: "peak_energy",
            text: "When's your peak energy?",
            subtitle: "We'll schedule your hardest tasks here",
            options: [
                AssessmentOption(id: "morning", label: "Morning", description: "Before noon"),
                AssessmentOption(id: "afternoon", label: "Afternoon", description: "1pm — 5pm"),
                AssessmentOption(id: "evening", label: "Evening", description: "After 6pm"),
                AssessmentOption(id: "inconsistent", label: "Inconsistent", description: "It varies day to day"),
            ],
            category: "cognitive"
        ),
        AssessmentQuestion(
            id: "overwhelm_response",
            text: "When everything piles up, what do you do?",
            options: [
                AssessmentOption(id: "shutdown", label: "Shut down", description: "Freeze and avoid everything"),
                AssessmentOption(id: "hyperfocus", label: "Hyperfocus on one thing", description: "Pick one and ignore the rest"),
                AssessmentOption(id: "scatter", label: "Scatter", description: "Start five things, finish none"),
            ],
            category: "cognitive"
        ),
        // Self-Awareness Baseline
        AssessmentQuestion(
            id: "adhd_focus",
            text: "How often do you have trouble keeping your attention on tasks?",
            subtitle: "Based on ASRS screening — be honest",
            options: [
                AssessmentOption(id: "never", label: "Never"),
                AssessmentOption(id: "rarely", label: "Rarely"),
                AssessmentOption(id: "sometimes", label: "Sometimes"),
                AssessmentOption(id: "often", label: "Often"),
                AssessmentOption(id: "very_often", label: "Very often"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "adhd_restless",
            text: "How often do you feel restless or fidgety?",
            options: [
                AssessmentOption(id: "never", label: "Never"),
                AssessmentOption(id: "rarely", label: "Rarely"),
                AssessmentOption(id: "sometimes", label: "Sometimes"),
                AssessmentOption(id: "often", label: "Often"),
                AssessmentOption(id: "very_often", label: "Very often"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "anxiety_level",
            text: "Over the last 2 weeks, how often have you felt nervous or on edge?",
            subtitle: "GAD-7 inspired — no judgment",
            options: [
                AssessmentOption(id: "not_at_all", label: "Not at all"),
                AssessmentOption(id: "several_days", label: "Several days"),
                AssessmentOption(id: "more_than_half", label: "More than half the days"),
                AssessmentOption(id: "nearly_every_day", label: "Nearly every day"),
            ],
            category: "baseline"
        ),
        AssessmentQuestion(
            id: "sleep_quality",
            text: "How would you rate your typical sleep?",
            options: [
                AssessmentOption(id: "great", label: "Great", description: "7-9 hrs, wake up refreshed"),
                AssessmentOption(id: "ok", label: "Okay", description: "Could be better, not terrible"),
                AssessmentOption(id: "poor", label: "Poor", description: "Inconsistent or not enough"),
                AssessmentOption(id: "terrible", label: "Terrible", description: "Major sleep problems"),
            ],
            category: "baseline"
        ),
        // Values & Priorities
        AssessmentQuestion(
            id: "top_values",
            text: "Pick your top 3 values",
            subtitle: "These guide how the app prioritizes your goals",
            options: [
                AssessmentOption(id: "health", label: "Health"),
                AssessmentOption(id: "career", label: "Career"),
                AssessmentOption(id: "learning", label: "Learning"),
                AssessmentOption(id: "relationships", label: "Relationships"),
                AssessmentOption(id: "freedom", label: "Freedom"),
                AssessmentOption(id: "creativity", label: "Creativity"),
                AssessmentOption(id: "wealth", label: "Wealth"),
                AssessmentOption(id: "impact", label: "Impact"),
            ],
            category: "values",
            multiSelect: true
        ),
        AssessmentQuestion(
            id: "biggest_blocker",
            text: "What's your biggest blocker right now?",
            options: [
                AssessmentOption(id: "time", label: "Not enough time"),
                AssessmentOption(id: "motivation", label: "Motivation"),
                AssessmentOption(id: "knowledge", label: "Don't know where to start"),
                AssessmentOption(id: "fear", label: "Fear / anxiety"),
                AssessmentOption(id: "habits", label: "Bad habits"),
                AssessmentOption(id: "focus", label: "Can't focus"),
            ],
            category: "values"
        ),
        AssessmentQuestion(
            id: "accountability",
            text: "How do you feel about accountability?",
            subtitle: "This controls how aggressive the app's nudges are",
            options: [
                AssessmentOption(id: "want_it", label: "I want it", description: "Push me hard, call me out"),
                AssessmentOption(id: "moderate", label: "Moderate", description: "Nudge me, don't nag me"),
                AssessmentOption(id: "gentle", label: "Gentle", description: "Suggest, don't pressure"),
            ],
            category: "values"
        ),
    ]
}
