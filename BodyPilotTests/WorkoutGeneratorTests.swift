import Foundation
import Testing
@testable import BodyPilot

struct WorkoutGeneratorTests {
    private let generator = WorkoutGenerator()

    private func recommendation(
        level: ReadinessLevel = .ready,
        durationRange: DurationRange = DurationRange(minMinutes: 25, maxMinutes: 30),
        activities: [ActivityType] = [.walking],
        intensity: WorkoutIntensity = .moderate,
        constraints: [WorkoutConstraint]? = nil
    ) -> DailyRecommendation {
        DailyRecommendation(
            level: level,
            recommendedDuration: durationRange,
            preferredActivities: activities,
            intensity: intensity,
            constraints: constraints ?? [.maxDuration(minutes: durationRange.maxMinutes)],
            rationaleFacts: []
        )
    }

    private func request(
        recommendation: DailyRecommendation,
        equipment: [EquipmentType] = [.none],
        timeLimitMinutes: Int? = nil
    ) -> WorkoutRequest {
        WorkoutRequest(
            recommendation: recommendation,
            goal: .generalFitness,
            equipment: equipment,
            timeLimitMinutes: timeLimitMinutes
        )
    }

    @Test("Workout fits inside the recommended duration")
    func fitsRecommendedDuration() throws {
        let workout = try generator.generateWorkout(for: request(recommendation: recommendation()))
        #expect(workout.totalMinutes <= 30)
        #expect(workout.totalMinutes >= WorkoutGenerator.minimumMinutes)
    }

    @Test("A user time limit overrides the recommendation")
    func timeLimitOverrides() throws {
        let workout = try generator.generateWorkout(
            for: request(recommendation: recommendation(), timeLimitMinutes: 15)
        )
        #expect(workout.totalMinutes <= 15)
    }

    @Test("Too little time throws instead of producing an unsafe plan")
    func notEnoughTime() {
        #expect(throws: WorkoutGenerationError.notEnoughTime) {
            try generator.generateWorkout(
                for: request(recommendation: recommendation(), timeLimitMinutes: 5)
            )
        }
    }

    @Test("Structure is always warm-up first, cool-down last")
    func structure() throws {
        for activity in [ActivityType.walking, .strength, .mobility, .recovery, .core] {
            let workout = try generator.generateWorkout(
                for: request(recommendation: recommendation(activities: [activity]))
            )
            #expect(workout.steps.first?.phase == .warmup)
            #expect(workout.steps.last?.phase == .cooldown)
            #expect(workout.steps.contains { $0.phase == .main })
        }
    }

    @Test("Bodyweight-only users never get equipment exercises")
    func equipmentRespected() throws {
        let workout = try generator.generateWorkout(
            for: request(recommendation: recommendation(activities: [.strength]), equipment: [.none])
        )
        #expect(workout.steps.allSatisfy { $0.requiredEquipment == nil })
    }

    @Test("Home gym unlocks band and dumbbell exercises without failing validation")
    func homeGymEquipment() throws {
        let workout = try generator.generateWorkout(
            for: request(recommendation: recommendation(activities: [.strength]), equipment: [.homeGym])
        )
        #expect(!workout.steps.isEmpty)
    }

    @Test("Sore areas are never loaded by any step")
    func sorenessRespected() throws {
        let sore: [SorenessArea] = [.legs, .knee]
        let rec = recommendation(
            activities: [.strength],
            constraints: [.maxDuration(minutes: 30)] + sore.map { .avoidSorenessArea($0) }
        )
        let workout = try generator.generateWorkout(for: request(recommendation: rec))
        for step in workout.steps {
            #expect(Set(step.stressedAreas).isDisjoint(with: sore))
        }
    }

    @Test("Step intensity never exceeds the recommended intensity")
    func intensityNeverExceeds() throws {
        for intensity in WorkoutIntensity.allCases {
            let workout = try generator.generateWorkout(
                for: request(recommendation: recommendation(intensity: intensity))
            )
            #expect(workout.intensity.rank <= intensity.rank)
            #expect(workout.steps.allSatisfy { $0.intensity.rank <= intensity.rank })
        }
    }

    @Test("The tightest max-duration constraint wins over the recommended range")
    func tightestConstraintWins() throws {
        let rec = recommendation(
            durationRange: DurationRange(minMinutes: 25, maxMinutes: 45),
            constraints: [.maxDuration(minutes: 45), .maxDuration(minutes: 20)]
        )
        let workout = try generator.generateWorkout(for: request(recommendation: rec))
        #expect(workout.totalMinutes <= 20)
    }

    @Test("Every supported V1 activity generates a valid workout across durations")
    func allActivitiesAndDurations() throws {
        let activities: [ActivityType] = [
            .walking, .strength, .mobility, .balance, .stretching, .core, .recovery, .chairExercise,
        ]
        for activity in activities {
            for minutes in [10, 20, 45] {
                let rec = recommendation(
                    durationRange: DurationRange(minMinutes: 10, maxMinutes: minutes),
                    activities: [activity]
                )
                let workout = try generator.generateWorkout(for: request(recommendation: rec))
                #expect(workout.totalMinutes <= minutes)
                #expect(!workout.steps.isEmpty)
            }
        }
    }

    @Test("Chair exercise produces seated step-by-step guidance")
    func chairExerciseGuidance() throws {
        let workout = try generator.generateWorkout(
            for: request(
                recommendation: recommendation(
                    durationRange: DurationRange(minMinutes: 10, maxMinutes: 10),
                    activities: [.chairExercise],
                    intensity: .light
                )
            )
        )

        #expect(workout.activity == .chairExercise)
        #expect(workout.steps.first?.name == String(localized: "Seated warm-up"))
        #expect(workout.steps.contains { $0.name == String(localized: "Seated marches") })
        #expect(workout.steps.allSatisfy { !$0.detail.isEmpty })
        #expect(workout.steps.allSatisfy { !($0.coachingCue?.isEmpty ?? true) })
    }

    @Test("Validation rejects a hand-built workout that violates soreness constraints")
    func validationCatchesViolations() {
        let rec = recommendation(constraints: [.maxDuration(minutes: 30), .avoidSorenessArea(.back)])
        let bad = PlannedWorkout(
            title: "Bad",
            activity: .strength,
            intensity: .moderate,
            steps: [
                WorkoutStep(phase: .warmup, name: "W", detail: "", durationMinutes: 3, intensity: .light),
                WorkoutStep(phase: .main, name: "Deadlifts", detail: "", durationMinutes: 10, intensity: .moderate, stressedAreas: [.back]),
                WorkoutStep(phase: .cooldown, name: "C", detail: "", durationMinutes: 3, intensity: .light),
            ],
            explanation: ""
        )
        #expect(throws: WorkoutGenerationError.self) {
            try generator.validate(bad, against: request(recommendation: rec))
        }
    }
}
