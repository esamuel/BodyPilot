import Foundation
import Observation

/// Drives the Apple Health connection card on Today.
/// UI-facing state only — all HealthKit access goes through HealthDataProviding.
@MainActor
@Observable
final class HealthAccessModel {
    enum ConnectionState: Equatable {
        case checking
        case unavailable
        case needsRequest
        case connected
        case failed(String)
    }

    private(set) var state: ConnectionState = .checking
    private let healthProvider: any HealthDataProviding

    init(healthProvider: any HealthDataProviding = HealthKitClient()) {
        self.healthProvider = healthProvider
    }

    func refresh() async {
        guard healthProvider.isHealthDataAvailable else {
            state = .unavailable
            return
        }
        do {
            state = try await healthProvider.authorizationRequestNeeded() ? .needsRequest : .connected
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func connect() async {
        do {
            try await healthProvider.requestAuthorization()
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
