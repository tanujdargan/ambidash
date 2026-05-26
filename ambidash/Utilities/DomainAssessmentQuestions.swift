// ambidash/Utilities/DomainAssessmentQuestions.swift
import Foundation

enum DomainAssessmentQuestions {
    static func questions(for domain: GoalDomain) -> [AssessmentQuestion] {
        switch domain {
        case .fitness:
            return [
                AssessmentQuestion(
                    id: "fitness_level",
                    text: "What's your current activity level?",
                    options: [
                        AssessmentOption(id: "sedentary", label: "Sedentary", description: "Little to no exercise"),
                        AssessmentOption(id: "light", label: "Light", description: "1-2 times per week"),
                        AssessmentOption(id: "moderate", label: "Moderate", description: "3-4 times per week"),
                        AssessmentOption(id: "active", label: "Very active", description: "5+ times per week"),
                    ],
                    category: "fitness"
                ),
                AssessmentQuestion(
                    id: "fitness_goal",
                    text: "What's your main body goal?",
                    options: [
                        AssessmentOption(id: "lose_fat", label: "Lose fat"),
                        AssessmentOption(id: "gain_muscle", label: "Build muscle"),
                        AssessmentOption(id: "endurance", label: "Improve endurance"),
                        AssessmentOption(id: "maintain", label: "Maintain current shape"),
                    ],
                    category: "fitness"
                ),
            ]
        case .cognitive:
            return [
                AssessmentQuestion(
                    id: "learning_style",
                    text: "How do you learn best?",
                    options: [
                        AssessmentOption(id: "reading", label: "Reading"),
                        AssessmentOption(id: "video", label: "Video/courses"),
                        AssessmentOption(id: "hands_on", label: "Hands-on building"),
                        AssessmentOption(id: "discussion", label: "Discussion/teaching"),
                    ],
                    category: "cognitive"
                ),
                AssessmentQuestion(
                    id: "daily_learning_time",
                    text: "How much time can you dedicate to learning daily?",
                    options: [
                        AssessmentOption(id: "15min", label: "15 minutes"),
                        AssessmentOption(id: "30min", label: "30 minutes"),
                        AssessmentOption(id: "1hr", label: "1 hour"),
                        AssessmentOption(id: "2hr_plus", label: "2+ hours"),
                    ],
                    category: "cognitive"
                ),
            ]
        case .social:
            return [
                AssessmentQuestion(
                    id: "social_anxiety",
                    text: "How would you describe your social comfort?",
                    options: [
                        AssessmentOption(id: "comfortable", label: "Generally comfortable"),
                        AssessmentOption(id: "situational", label: "Depends on the situation"),
                        AssessmentOption(id: "anxious", label: "Usually anxious"),
                        AssessmentOption(id: "avoidant", label: "I avoid social situations"),
                    ],
                    category: "social"
                ),
                AssessmentQuestion(
                    id: "social_goal",
                    text: "What matters most to you socially?",
                    options: [
                        AssessmentOption(id: "confidence", label: "Building confidence"),
                        AssessmentOption(id: "network", label: "Growing my network"),
                        AssessmentOption(id: "deeper", label: "Deeper existing relationships"),
                        AssessmentOption(id: "dating", label: "Finding a partner"),
                    ],
                    category: "social"
                ),
            ]
        case .career:
            return [
                AssessmentQuestion(
                    id: "career_stage",
                    text: "Where are you in your career?",
                    options: [
                        AssessmentOption(id: "student", label: "Student", description: "Still in school"),
                        AssessmentOption(id: "early", label: "Early career", description: "0-2 years"),
                        AssessmentOption(id: "mid", label: "Mid career", description: "3-7 years"),
                        AssessmentOption(id: "transition", label: "Career transition"),
                    ],
                    category: "career"
                ),
                AssessmentQuestion(
                    id: "career_goal",
                    text: "What's your primary career goal?",
                    options: [
                        AssessmentOption(id: "big_tech", label: "Get into a top company"),
                        AssessmentOption(id: "startup", label: "Build my own company"),
                        AssessmentOption(id: "skills", label: "Deepen technical skills"),
                        AssessmentOption(id: "leadership", label: "Move into leadership"),
                    ],
                    category: "career"
                ),
            ]
        case .language:
            return [
                AssessmentQuestion(
                    id: "language_level",
                    text: "What's your current level?",
                    options: [
                        AssessmentOption(id: "beginner", label: "Beginner", description: "Know a few words"),
                        AssessmentOption(id: "elementary", label: "Elementary", description: "Basic conversations"),
                        AssessmentOption(id: "intermediate", label: "Intermediate", description: "Can hold a conversation"),
                        AssessmentOption(id: "advanced", label: "Advanced", description: "Want to refine fluency"),
                    ],
                    category: "language"
                ),
            ]
        case .screenTime:
            return [
                AssessmentQuestion(
                    id: "screen_hours",
                    text: "How many hours do you typically spend on your phone?",
                    options: [
                        AssessmentOption(id: "2_3", label: "2-3 hours"),
                        AssessmentOption(id: "4_5", label: "4-5 hours"),
                        AssessmentOption(id: "6_7", label: "6-7 hours"),
                        AssessmentOption(id: "8_plus", label: "8+ hours"),
                    ],
                    category: "screenTime"
                ),
            ]
        case .financial:
            return [
                AssessmentQuestion(
                    id: "financial_goal",
                    text: "What's your financial priority?",
                    options: [
                        AssessmentOption(id: "save", label: "Build savings"),
                        AssessmentOption(id: "debt", label: "Pay off debt"),
                        AssessmentOption(id: "invest", label: "Start investing"),
                        AssessmentOption(id: "income", label: "Increase income"),
                    ],
                    category: "financial"
                ),
            ]
        }
    }
}
