import Foundation

/// Deterministic synthetic health data for previews and tests.
/// Values are generated from a seed — never derived from real user data.
struct MockHealthProvider: HealthDataProviding, HealthMetricsProviding {
    var isHealthDataAvailable: Bool { true }
    var authorizationNeeded = false
    var seed: UInt64 = 42

    func authorizationRequestNeeded() async throws -> Bool {
        authorizationNeeded
    }

    func requestAuthorization() async throws {
        // Nothing to request for synthetic data.
    }

    func dailySnapshots(from startDate: Date, to endDate: Date) async throws -> [DailyHealthSnapshot] {
        let calendar = Calendar.current
        var snapshots: [DailyHealthSnapshot] = []
        var day = calendar.startOfDay(for: startDate)
        var index = 0
        while day <= endDate {
            snapshots.append(snapshot(for: day, index: index))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }
        return snapshots
    }

    func workouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSummary] {
        let snapshots = try await dailySnapshots(from: startDate, to: endDate)
        // A plausible pattern: a walk roughly every other day.
        return snapshots.enumerated().compactMap { index, snapshot in
            guard index.isMultiple(of: 2) else { return nil }
            return WorkoutSummary(
                start: snapshot.date.addingTimeInterval(9 * 3600),
                durationMinutes: 25 + Double(noise(day: index, salt: 7) * 20),
                activity: .walking,
                totalEnergyKilocalories: 120 + Double(noise(day: index, salt: 8) * 80)
            )
        }
    }

    private func snapshot(for day: Date, index: Int) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: day,
            sleepHours: 6.5 + Double(noise(day: index, salt: 1)) * 2.0,
            hrvSDNN: 45 + Double(noise(day: index, salt: 2)) * 20,
            restingHeartRate: 58 + Double(noise(day: index, salt: 3)) * 6,
            steps: 5_000 + Double(noise(day: index, salt: 4)) * 6_000,
            activeEnergyKilocalories: 300 + Double(noise(day: index, salt: 5)) * 250,
            exerciseMinutes: 15 + Double(noise(day: index, salt: 6)) * 30
        )
    }

    /// Deterministic pseudo-random value in 0..<1 derived from the seed, day index, and salt.
    private func noise(day: Int, salt: UInt64) -> Float {
        var state = seed &+ UInt64(day) &* 0x9E37_79B9_7F4A_7C15 &+ salt &* 0xBF58_476D_1CE4_E5B9
        state = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
        state = (state ^ (state >> 27)) &* 0x94D0_49BB_1331_11EB
        state ^= state >> 31
        return Float(state % 10_000) / 10_000
    }
}
