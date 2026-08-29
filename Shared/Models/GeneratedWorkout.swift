import Foundation
import SwiftData

/// A workout produced by the workout generator, persisted for history and reuse.
@Model
final class GeneratedWorkout {
    var createdAt: Date
    var title: String
    var activity: ActivityType
    var durationMinutes: Int
    var intensity: WorkoutIntensity
    var explanation: String
    var steps: [WorkoutStep]
    var completedAt: Date?

    init(
        createdAt: Date = .now,
        title: String,
        activity: ActivityType,
        durationMinutes: Int,
        intensity: WorkoutIntensity,
        explanation: String,
        steps: [WorkoutStep] = [],
        completedAt: Date? = nil
    ) {
        self.createdAt = createdAt
        self.title = title
        self.activity = activity
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.explanation = explanation
        self.steps = steps
        self.completedAt = completedAt
    }
}

extension GeneratedWorkout {
    convenience init(plan: PlannedWorkout) {
        self.init(
            title: plan.title,
            activity: plan.activity,
            durationMinutes: plan.totalMinutes,
            intensity: plan.intensity,
            explanation: plan.explanation,
            steps: plan.steps
        )
    }
}
