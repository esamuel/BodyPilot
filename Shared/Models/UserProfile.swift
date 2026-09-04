import Foundation
import SwiftData

/// Optional biological sex, stored on-device and used only for personalization
/// such as heart-rate zone estimates. Never leaves the device.
enum BiologicalSexOption: String, Codable, CaseIterable, Sendable {
    case female
    case male
    case notSpecified
}

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
    var biologicalSex: BiologicalSexOption?
    var birthDate: Date?
    /// Small JPEG chosen by the user for their avatar; stays on-device.
    @Attribute(.externalStorage) var avatarImageData: Data?
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
        biologicalSex: BiologicalSexOption? = nil,
        birthDate: Date? = nil,
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
        self.biologicalSex = biologicalSex
        self.birthDate = birthDate
        self.createdAt = createdAt
    }

    /// Whole years since `birthDate`; nil when the user hasn't provided one.
    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: .now).year
    }
}
