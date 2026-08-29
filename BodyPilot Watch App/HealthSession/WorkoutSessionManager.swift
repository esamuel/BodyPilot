import Foundation
import HealthKit
import Observation
import WatchKit

/// Runs the live HealthKit workout session on the Watch: session lifecycle,
/// live metrics, deterministic step progression with haptics, and the final
/// save to HealthKit (which syncs back to the iPhone's load engine).
@MainActor
@Observable
final class WorkoutSessionManager: NSObject {
    enum Phase: Equatable {
        case idle
        case active
        case paused
        case summary
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var plan: PlannedWorkout?
    private(set) var heartRate: Double?
    private(set) var averageHeartRate: Double?
    private(set) var activeEnergyKilocalories: Double?
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var currentStepIndex: Int?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var ticker: Task<Void, Never>?

    var currentStep: WorkoutStep? {
        guard let plan, let currentStepIndex, plan.steps.indices.contains(currentStepIndex) else {
            return nil
        }
        return plan.steps[currentStepIndex]
    }

    var nextStep: WorkoutStep? {
        guard let plan, let currentStepIndex, plan.steps.indices.contains(currentStepIndex + 1) else {
            return nil
        }
        return plan.steps[currentStepIndex + 1]
    }

    var remainingMinutesInStep: Double? {
        plan?.remainingMinutes(atMinutes: elapsedSeconds / 60)
    }

    // MARK: - Lifecycle

    func start(plan: PlannedWorkout) async {
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = plan.activity.workoutActivityType
        configuration.locationType = plan.activity.defaultLocationType

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            self.plan = plan

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            phase = .active
            currentStepIndex = 0
            WKInterfaceDevice.current().play(.start)
            startTicker()
        } catch {
            reset()
            phase = .failed(error.localizedDescription)
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func end() {
        session?.end()
    }

    /// Saves the workout (with the user's perceived effort as metadata) and
    /// returns to idle. Called from the summary screen.
    func finish(perceivedEffort: String?) async {
        let builder = builder
        reset()
        guard let builder else { return }
        do {
            if let perceivedEffort {
                try await builder.addMetadata(["com.bodypilot.perceivedEffort": perceivedEffort])
            }
            _ = try await builder.finishWorkout()
        } catch {
            // Collection already ended; a save failure must not trap the user
            // on the summary screen. The session data stays recoverable in HealthKit.
        }
    }

    // MARK: - Ticker (deterministic step machine)

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard phase == .active, let builder, let plan else { return }
        elapsedSeconds = builder.elapsedTime
        let newIndex = plan.stepIndex(atMinutes: elapsedSeconds / 60)
        if newIndex != currentStepIndex {
            currentStepIndex = newIndex
            // Haptic per step transition; success chime once all steps are done.
            WKInterfaceDevice.current().play(newIndex == nil ? .success : .directionUp)
        }
    }

    private func refreshMetrics() {
        guard let builder else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        if let heartRateStats = builder.statistics(for: HKQuantityType(.heartRate)) {
            heartRate = heartRateStats.mostRecentQuantity()?.doubleValue(for: bpmUnit)
            averageHeartRate = heartRateStats.averageQuantity()?.doubleValue(for: bpmUnit)
        }
        if let energyStats = builder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            activeEnergyKilocalories = energyStats.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
    }

    private func handleSessionState(_ state: HKWorkoutSessionState, at date: Date) async {
        switch state {
        case .running:
            if phase == .paused {
                phase = .active
                WKInterfaceDevice.current().play(.start)
            }
        case .paused:
            phase = .paused
            WKInterfaceDevice.current().play(.stop)
        case .ended:
            ticker?.cancel()
            try? await builder?.endCollection(at: date)
            refreshMetrics()
            phase = .summary
            WKInterfaceDevice.current().play(.success)
        default:
            break
        }
    }

    private func reset() {
        ticker?.cancel()
        ticker = nil
        session = nil
        builder = nil
        plan = nil
        heartRate = nil
        averageHeartRate = nil
        activeEnergyKilocalories = nil
        elapsedSeconds = 0
        currentStepIndex = nil
        phase = .idle
    }
}

// MARK: - HealthKit delegates (nonisolated callbacks hop to the main actor)

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            await self.handleSessionState(toState, at: date)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.phase = .failed(message)
        }
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            self.refreshMetrics()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
