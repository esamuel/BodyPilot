import Foundation
import Observation

/// Drives the Progress screen: loads two periods of history (current + previous
/// for trend comparison) and runs the deterministic ProgressEngine.
@MainActor
@Observable
final class ProgressModel {
    enum State {
        case loading
        case ready(ProgressSummary)
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading

    private let healthMetrics: any HealthMetricsProviding
    private let engine = ProgressEngine()

    init(healthMetrics: any HealthMetricsProviding = HealthKitClient()) {
        self.healthMetrics = healthMetrics
    }

    func refresh(period: ProgressPeriod, now: Date = .now) async {
        guard let historyStart = Calendar.current.date(byAdding: .day, value: -2 * period.rawValue, to: now) else {
            state = .failed(String(localized: "Could not compute the date range."))
            return
        }
        do {
            async let snapshotsTask = healthMetrics.dailySnapshots(from: historyStart, to: now)
            async let workoutsTask = healthMetrics.workouts(from: historyStart, to: now)
            let snapshots = try await snapshotsTask
            let workouts = try await workoutsTask

            guard let summary = engine.summary(
                snapshots: snapshots,
                workouts: workouts,
                period: period,
                asOf: now
            ) else {
                state = .failed(String(localized: "Could not compute the date range."))
                return
            }
            state = summary.hasAnyData ? .ready(summary) : .empty
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
