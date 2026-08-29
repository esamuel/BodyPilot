import Foundation

/// One step of a generated workout.
struct WorkoutStep: Codable, Hashable, Sendable {
    enum Phase: String, Codable, Hashable, Sendable {
        case warmup
        case main
        case cooldown
    }

    let phase: Phase
    let name: String
    let detail: String
    let durationMinutes: Int
    let intensity: WorkoutIntensity
    /// Short form/safety cue shown while following the step.
    let coachingCue: String?
    /// Equipment this step needs; nil means bodyweight only.
    let requiredEquipment: EquipmentType?
    /// Body areas this step loads — used to honor soreness constraints.
    let stressedAreas: [SorenessArea]

    init(
        phase: Phase,
        name: String,
        detail: String,
        durationMinutes: Int,
        intensity: WorkoutIntensity,
        coachingCue: String? = nil,
        requiredEquipment: EquipmentType? = nil,
        stressedAreas: [SorenessArea] = []
    ) {
        self.phase = phase
        self.name = name
        self.detail = detail
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.coachingCue = coachingCue
        self.requiredEquipment = requiredEquipment
        self.stressedAreas = stressedAreas
    }
}

/// A fully generated, validated workout ready for display or start.
struct PlannedWorkout: Codable, Hashable, Sendable {
    let title: String
    let activity: ActivityType
    let intensity: WorkoutIntensity
    let steps: [WorkoutStep]
    let explanation: String

    nonisolated var totalMinutes: Int {
        steps.reduce(0) { $0 + $1.durationMinutes }
    }
}

// MARK: - Deterministic step progression (drives live Watch coaching)

extension PlannedWorkout {
    /// The step in progress at `elapsedMinutes`; nil once all steps are done.
    nonisolated func stepIndex(atMinutes elapsedMinutes: Double) -> Int? {
        var cumulative = 0.0
        for (index, step) in steps.enumerated() {
            cumulative += Double(step.durationMinutes)
            if elapsedMinutes < cumulative {
                return index
            }
        }
        return nil
    }

    /// Minutes remaining in the current step; nil once all steps are done.
    nonisolated func remainingMinutes(atMinutes elapsedMinutes: Double) -> Double? {
        var cumulative = 0.0
        for step in steps {
            cumulative += Double(step.durationMinutes)
            if elapsedMinutes < cumulative {
                return cumulative - elapsedMinutes
            }
        }
        return nil
    }
}
