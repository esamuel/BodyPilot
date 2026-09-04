import Foundation

/// Everything the recommendation engine considers for one day.
struct RecommendationInput: Sendable {
    let scoreResult: BodyScoreResult
    let preferredActivities: [ActivityType]
    let preferredWorkoutMinutes: Int
    let equipment: [EquipmentType]
    let soreness: [SorenessArea]
    let feeling: FeelingLevel?
    let corridorDay: CorridorDay?

    nonisolated init(
        scoreResult: BodyScoreResult,
        preferredActivities: [ActivityType],
        preferredWorkoutMinutes: Int,
        equipment: [EquipmentType],
        soreness: [SorenessArea],
        feeling: FeelingLevel?,
        corridorDay: CorridorDay? = nil
    ) {
        self.scoreResult = scoreResult
        self.preferredActivities = preferredActivities
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
        self.equipment = equipment
        self.soreness = soreness
        self.feeling = feeling
        self.corridorDay = corridorDay
    }
}

/// Deterministic daily recommendation per PRD 7.2/7.6.
/// AI may rephrase the result but must never override its constraints.
struct RecommendationEngine: Sendable {
    func recommendation(for input: RecommendationInput) -> DailyRecommendation {
        let level = readinessLevel(for: input)
        let intensity = cappedIntensity(base: baseIntensity(for: level), input: input)
        let duration = durationRange(for: level, preferredMinutes: input.preferredWorkoutMinutes)
        let activities = activities(for: level, preferred: input.preferredActivities)

        var constraints: [WorkoutConstraint] = [.maxDuration(minutes: duration.maxMinutes)]
        if intensity.rank <= WorkoutIntensity.light.rank || level == .easy || level == .recover {
            constraints.append(.avoidHighIntensity)
        }
        constraints.append(contentsOf: input.soreness.map { WorkoutConstraint.avoidSorenessArea($0) })
        if !input.equipment.isEmpty {
            constraints.append(.equipmentLimit(input.equipment))
        }

        var facts = input.scoreResult.explanationFacts
        facts.append(planFact(for: level))

        return DailyRecommendation(
            level: level,
            recommendedDuration: duration,
            preferredActivities: activities,
            intensity: intensity,
            constraints: constraints,
            rationaleFacts: facts
        )
    }

    // MARK: - Intensity

    private func readinessLevel(for input: RecommendationInput) -> ReadinessLevel {
        guard let corridorDay = input.corridorDay else {
            return input.scoreResult.readiness
        }
        if corridorDay.isRestRecommended {
            return .recover
        }
        return switch corridorDay.state {
        case .above: .recover
        case .inside: .ready
        case .below: .strong
        }
    }

    private func baseIntensity(for level: ReadinessLevel) -> WorkoutIntensity {
        switch level {
        case .strong: .hard
        case .ready: .moderate
        case .easy: .light
        case .recover: .recovery
        }
    }

    /// Deterministic conflict handling: a bad subjective day or general soreness
    /// always caps intensity, regardless of physiological signals.
    private func cappedIntensity(base: WorkoutIntensity, input: RecommendationInput) -> WorkoutIntensity {
        var cap: WorkoutIntensity = .hard
        switch input.feeling {
        case .veryTired: cap = .recovery
        case .tired: cap = .light
        default: break
        }
        if input.soreness.contains(.general) {
            cap = minIntensity(cap, .light)
        }
        return minIntensity(base, cap)
    }

    private func minIntensity(_ a: WorkoutIntensity, _ b: WorkoutIntensity) -> WorkoutIntensity {
        a.rank <= b.rank ? a : b
    }

    // MARK: - Duration

    private func durationRange(for level: ReadinessLevel, preferredMinutes: Int) -> DurationRange {
        let preferred = max(preferredMinutes, 10)
        switch level {
        case .strong:
            return DurationRange(minMinutes: preferred, maxMinutes: preferred + 15)
        case .ready:
            return DurationRange(minMinutes: max(10, preferred - 5), maxMinutes: preferred)
        case .easy:
            let upper = min(preferred, 30)
            return DurationRange(minMinutes: min(20, upper), maxMinutes: upper)
        case .recover:
            return DurationRange(minMinutes: 10, maxMinutes: 20)
        }
    }

    // MARK: - Activities

    private func activities(for level: ReadinessLevel, preferred: [ActivityType]) -> [ActivityType] {
        switch level {
        case .strong, .ready:
            return preferred.isEmpty ? [.walking] : preferred
        case .easy:
            let allowed: Set<ActivityType> = [
                .walking, .mobility, .stretching, .balance, .chairExercise, .recovery, .swimming, .cycling,
            ]
            let matches = preferred.filter(allowed.contains)
            return matches.isEmpty ? [.walking, .stretching] : matches
        case .recover:
            let allowed: Set<ActivityType> = [.recovery, .stretching, .mobility, .walking]
            let matches = preferred.filter(allowed.contains)
            return matches.isEmpty ? [.recovery, .stretching] : matches
        }
    }

    // MARK: - Rationale

    private func planFact(for level: ReadinessLevel) -> ExplanationFact {
        let detail: String = switch level {
        case .strong: String(localized: "Your signals look strong — a solid session fits today.")
        case .ready: String(localized: "You're ready for your usual training today.")
        case .easy: String(localized: "Today favors moderate, comfortable activity over a hard session.")
        case .recover: String(localized: "Your body is asking for recovery — gentle movement helps most today.")
        }
        return ExplanationFact(title: String(localized: "Plan"), detail: detail)
    }
}
