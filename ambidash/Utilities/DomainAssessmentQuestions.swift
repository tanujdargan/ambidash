// ambidash/Utilities/DomainAssessmentQuestions.swift
import Foundation

enum DomainAssessmentQuestions {
    static func questions(for domain: GoalDomain) -> [AssessmentQuestion] {
        switch domain {
        case .body:
            return [
                AssessmentQuestion(
                    id: "body_activity_level",
                    text: "What's your current activity level?",
                    options: [
                        AssessmentOption(id: "sedentary", label: "Sedentary", description: "Little to no exercise"),
                        AssessmentOption(id: "light", label: "Light", description: "1-2 times per week"),
                        AssessmentOption(id: "moderate", label: "Moderate", description: "3-4 times per week"),
                        AssessmentOption(id: "active", label: "Very active", description: "5+ times per week"),
                    ],
                    category: "body"
                ),
                AssessmentQuestion(
                    id: "body_goal",
                    text: "What's your main body goal?",
                    options: [
                        AssessmentOption(id: "lose_fat", label: "Lose fat"),
                        AssessmentOption(id: "gain_muscle", label: "Build muscle"),
                        AssessmentOption(id: "endurance", label: "Improve endurance"),
                        AssessmentOption(id: "maintain", label: "Maintain current shape"),
                    ],
                    category: "body"
                ),
            ]
        case .mind:
            return [
                AssessmentQuestion(
                    id: "mind_learning_style",
                    text: "How do you learn best?",
                    options: [
                        AssessmentOption(id: "reading", label: "Reading"),
                        AssessmentOption(id: "video", label: "Video/courses"),
                        AssessmentOption(id: "hands_on", label: "Hands-on building"),
                        AssessmentOption(id: "discussion", label: "Discussion/teaching"),
                    ],
                    category: "mind"
                ),
                AssessmentQuestion(
                    id: "mind_daily_time",
                    text: "How much time can you dedicate to mental growth daily?",
                    options: [
                        AssessmentOption(id: "15min", label: "15 minutes"),
                        AssessmentOption(id: "30min", label: "30 minutes"),
                        AssessmentOption(id: "1hr", label: "1 hour"),
                        AssessmentOption(id: "2hr_plus", label: "2+ hours"),
                    ],
                    category: "mind"
                ),
            ]
        case .craft:
            return [
                AssessmentQuestion(
                    id: "craft_stage",
                    text: "Where are you in your career?",
                    options: [
                        AssessmentOption(id: "student", label: "Student", description: "Still in school"),
                        AssessmentOption(id: "early", label: "Early career", description: "0-2 years"),
                        AssessmentOption(id: "mid", label: "Mid career", description: "3-7 years"),
                        AssessmentOption(id: "transition", label: "Career transition"),
                    ],
                    category: "craft"
                ),
                AssessmentQuestion(
                    id: "craft_goal",
                    text: "What's your primary craft goal?",
                    options: [
                        AssessmentOption(id: "big_tech", label: "Get into a top company"),
                        AssessmentOption(id: "startup", label: "Build my own company"),
                        AssessmentOption(id: "skills", label: "Deepen technical skills"),
                        AssessmentOption(id: "leadership", label: "Move into leadership"),
                    ],
                    category: "craft"
                ),
            ]
        case .people:
            return [
                AssessmentQuestion(
                    id: "people_comfort",
                    text: "How would you describe your social comfort?",
                    options: [
                        AssessmentOption(id: "comfortable", label: "Generally comfortable"),
                        AssessmentOption(id: "situational", label: "Depends on the situation"),
                        AssessmentOption(id: "anxious", label: "Usually anxious"),
                        AssessmentOption(id: "avoidant", label: "I avoid social situations"),
                    ],
                    category: "people"
                ),
                AssessmentQuestion(
                    id: "people_goal",
                    text: "What matters most to you in relationships?",
                    options: [
                        AssessmentOption(id: "confidence", label: "Building confidence"),
                        AssessmentOption(id: "network", label: "Growing my network"),
                        AssessmentOption(id: "deeper", label: "Deeper existing relationships"),
                        AssessmentOption(id: "dating", label: "Finding a partner"),
                    ],
                    category: "people"
                ),
            ]
        case .wealth:
            return [
                AssessmentQuestion(
                    id: "wealth_priority",
                    text: "What's your financial priority?",
                    options: [
                        AssessmentOption(id: "save", label: "Build savings"),
                        AssessmentOption(id: "debt", label: "Pay off debt"),
                        AssessmentOption(id: "invest", label: "Start investing"),
                        AssessmentOption(id: "income", label: "Increase income"),
                    ],
                    category: "wealth"
                ),
            ]
        case .adventure:
            return [
                AssessmentQuestion(
                    id: "adventure_style",
                    text: "What kind of experiences excite you most?",
                    options: [
                        AssessmentOption(id: "travel", label: "Travel & exploration"),
                        AssessmentOption(id: "outdoors", label: "Outdoor activities"),
                        AssessmentOption(id: "creative", label: "Creative experiences"),
                        AssessmentOption(id: "social", label: "Social adventures"),
                    ],
                    category: "adventure"
                ),
                AssessmentQuestion(
                    id: "adventure_frequency",
                    text: "How often do you seek new experiences?",
                    options: [
                        AssessmentOption(id: "rarely", label: "Rarely", description: "I stick to routines"),
                        AssessmentOption(id: "monthly", label: "Monthly", description: "Once in a while"),
                        AssessmentOption(id: "weekly", label: "Weekly", description: "Regularly"),
                        AssessmentOption(id: "daily", label: "Daily", description: "Always exploring"),
                    ],
                    category: "adventure"
                ),
            ]
        }
    }
}
