import Foundation
import SwiftData

/// The user's onboarding choices and long-lived preferences.
@Model
final class UserProfile {
    var displayName: String?
    var onboardingGoals: [OnboardingGoal]?
    var goal: FitnessGoal
    var activityFrequency: ActivityFrequency
    var preferredActivities: [ActivityType]
    var equipment: [EquipmentType]
    var preferredWorkoutMinutes: Int
    var hasCompletedOnboarding: Bool
    var sleepGoalHours: Double?
    var createdAt: Date

    init(
        displayName: String? = nil,
        onboardingGoals: [OnboardingGoal]? = nil,
        goal: FitnessGoal = .generalFitness,
        activityFrequency: ActivityFrequency = .occasional,
        preferredActivities: [ActivityType] = [.walking],
        equipment: [EquipmentType] = [.none],
        preferredWorkoutMinutes: Int = 30,
        hasCompletedOnboarding: Bool = false,
        sleepGoalHours: Double? = nil,
        createdAt: Date = .now
    ) {
        self.displayName = displayName
        self.onboardingGoals = onboardingGoals
        self.goal = goal
        self.activityFrequency = activityFrequency
        self.preferredActivities = preferredActivities
        self.equipment = equipment
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.sleepGoalHours = sleepGoalHours
        self.createdAt = createdAt
    }
}
