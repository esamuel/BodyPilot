import Foundation

/// Everything the generator needs for one workout.
struct WorkoutRequest: Sendable {
    let recommendation: DailyRecommendation
    let goal: FitnessGoal
    let equipment: [EquipmentType]
    /// User-imposed time cap ("I only have 15 minutes"); nil uses the recommendation.
    let timeLimitMinutes: Int?
}

enum WorkoutGenerationError: LocalizedError, Equatable {
    case notEnoughTime
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notEnoughTime:
            String(localized: "There isn't enough time for a safe workout. Try at least 10 minutes.")
        case .validationFailed(let reason):
            String(localized: "The generated workout failed validation: \(reason)")
        }
    }
}

/// Lets App Intents surface a real message instead of a generic failure.
extension WorkoutGenerationError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notEnoughTime:
            "There isn't enough time for a safe workout. Try at least 10 minutes."
        case .validationFailed:
            "The workout couldn't be generated safely. Try different options."
        }
    }
}

/// Rules-first workout generation per PRD 7.6. Every workout is validated
/// against the recommendation's constraints before it can be shown or started.
struct WorkoutGenerator: Sendable {
    /// Shortest workout worth generating.
    static let minimumMinutes = 10

    func generateWorkout(for request: WorkoutRequest) throws -> PlannedWorkout {
        let recommendation = request.recommendation

        var targetMinutes = min(recommendation.recommendedDuration.maxMinutes, maxAllowedMinutes(for: recommendation))
        if let limit = request.timeLimitMinutes {
            targetMinutes = min(targetMinutes, limit)
        }
        guard targetMinutes >= Self.minimumMinutes else {
            throw WorkoutGenerationError.notEnoughTime
        }

        let activity = recommendation.preferredActivities.first ?? .walking
        let steps = WorkoutTemplates.steps(
            activity: activity,
            intensity: recommendation.intensity,
            totalMinutes: targetMinutes,
            equipment: request.equipment,
            avoiding: avoidedAreas(for: recommendation)
        )

        let workout = PlannedWorkout(
            title: String(localized: "\(String(localized: activity.displayName)) · \(targetMinutes) min"),
            activity: activity,
            intensity: recommendation.intensity,
            steps: steps,
            explanation: String(
                localized: "Built for today's readiness: \(String(localized: recommendation.intensity.displayName).lowercased()) intensity, within your \(targetMinutes)-minute window."
            )
        )
        try validate(workout, against: request)
        return workout
    }

    // MARK: - Validation

    /// Every generated workout must pass before display or start.
    func validate(_ workout: PlannedWorkout, against request: WorkoutRequest) throws {
        let recommendation = request.recommendation

        guard !workout.steps.isEmpty else {
            throw WorkoutGenerationError.validationFailed(String(localized: "no steps"))
        }
        guard workout.steps.first?.phase == .warmup, workout.steps.last?.phase == .cooldown else {
            throw WorkoutGenerationError.validationFailed(String(localized: "missing warm-up or cool-down"))
        }

        let maxMinutes = maxAllowedMinutes(for: recommendation)
        let limit = request.timeLimitMinutes.map { min($0, maxMinutes) } ?? maxMinutes
        guard workout.totalMinutes <= limit else {
            throw WorkoutGenerationError.validationFailed(String(localized: "exceeds the time limit"))
        }

        guard workout.intensity.rank <= recommendation.intensity.rank,
              workout.steps.allSatisfy({ $0.intensity.rank <= recommendation.intensity.rank }) else {
            throw WorkoutGenerationError.validationFailed(String(localized: "exceeds the allowed intensity"))
        }

        let available = availableEquipment(request.equipment)
        guard workout.steps.allSatisfy({ $0.requiredEquipment.map(available.contains) ?? true }) else {
            throw WorkoutGenerationError.validationFailed(String(localized: "requires unavailable equipment"))
        }

        let avoided = Set(avoidedAreas(for: recommendation))
        guard workout.steps.allSatisfy({ Set($0.stressedAreas).isDisjoint(with: avoided) }) else {
            throw WorkoutGenerationError.validationFailed(String(localized: "loads a sore area"))
        }
    }

    // MARK: - Constraint extraction

    private func maxAllowedMinutes(for recommendation: DailyRecommendation) -> Int {
        let constrained = recommendation.constraints.compactMap { constraint in
            if case .maxDuration(let minutes) = constraint { minutes } else { Int?.none }
        }
        return constrained.min() ?? recommendation.recommendedDuration.maxMinutes
    }

    private func avoidedAreas(for recommendation: DailyRecommendation) -> [SorenessArea] {
        recommendation.constraints.compactMap { constraint in
            if case .avoidSorenessArea(let area) = constraint { area } else { SorenessArea?.none }
        }
    }

    private func availableEquipment(_ equipment: [EquipmentType]) -> Set<EquipmentType> {
        var available = Set(equipment)
        if available.contains(.homeGym) || available.contains(.fullGym) {
            available.formUnion([.resistanceBands, .dumbbells])
        }
        return available
    }
}
