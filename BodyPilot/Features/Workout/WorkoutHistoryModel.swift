import Foundation
import Observation

/// Loads recent real workouts from Apple Health (any source — Watch sessions,
/// other apps) so the Workout tab reflects what the user actually did.
@MainActor
@Observable
final class WorkoutHistoryModel {
    private(set) var recentWorkouts: [WorkoutSummary] = []

    private let healthMetrics: any HealthMetricsProviding

    init(healthMetrics: any HealthMetricsProviding = HealthKitClient()) {
        self.healthMetrics = healthMetrics
    }

    func refresh(now: Date = .now) async {
        guard let start = Calendar.current.date(byAdding: .day, value: -14, to: now) else {
            return
        }
        recentWorkouts = (try? await healthMetrics.workouts(from: start, to: now)) ?? []
    }
}
