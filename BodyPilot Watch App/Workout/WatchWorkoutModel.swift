import Foundation
import Observation

/// Builds today's recommended workout directly on the Watch using the shared
/// readiness pipeline, so the Watch works even without the iPhone nearby.
@MainActor
@Observable
final class WatchWorkoutModel {
    enum State {
        case loading
        case needsHealthAccess
        case ready(PlannedWorkout)
        case failed(String)
    }

    private(set) var state: State = .loading
    /// Always-available fallback options that need no health history.
    private(set) var quickPlans: [PlannedWorkout] = []

    private let healthClient = HealthKitClient()
    private let readiness: ReadinessService
    private let generator = WorkoutGenerator()
    private let profileSync: WatchProfileSyncService

    init(profileSync: WatchProfileSyncService = .shared) {
        self.profileSync = profileSync
        readiness = ReadinessService(healthMetrics: healthClient)
        profileSync.activate()
    }

    func load(now: Date = .now) async {
        quickPlans = makeQuickPlans()

        guard healthClient.isHealthDataAvailable else {
            state = .failed(String(localized: "Health data isn't available."))
            return
        }
        do {
            if try await healthClient.authorizationRequestNeeded() {
                state = .needsHealthAccess
                return
            }
            let preferences = profileSync.preferences.readinessPreferences
            let snapshot = try await readiness.snapshot(
                preferences: preferences,
                feeling: nil,
                soreness: [],
                now: now
            )
            let plan = try generator.generateWorkout(
                for: WorkoutRequest(
                    recommendation: snapshot.recommendation,
                    goal: preferences.goal,
                    equipment: preferences.equipment,
                    timeLimitMinutes: nil
                )
            )
            state = .ready(plan)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func requestAccess() async {
        do {
            try await healthClient.requestAuthorization()
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func makeQuickPlans() -> [PlannedWorkout] {
        let options: [(ActivityType, WorkoutIntensity, Int)] = [
            (.walking, .light, 20),
            (.recovery, .recovery, 10),
        ]
        return options.compactMap { activity, intensity, minutes in
            let recommendation = DailyRecommendation(
                level: .easy,
                recommendedDuration: DurationRange(minMinutes: minutes, maxMinutes: minutes),
                preferredActivities: [activity],
                intensity: intensity,
                constraints: [.maxDuration(minutes: minutes)],
                rationaleFacts: []
            )
            return try? generator.generateWorkout(
                for: WorkoutRequest(
                    recommendation: recommendation,
                    goal: .generalFitness,
                    equipment: [.none],
                    timeLimitMinutes: minutes
                )
            )
        }
    }
}
