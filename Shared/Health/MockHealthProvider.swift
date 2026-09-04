import Foundation

/// Deterministic synthetic health data for previews and tests.
/// Values are generated from a seed — never derived from real user data.
struct MockHealthProvider: HealthDataProviding, HealthMetricsProviding, SleepDataProviding {
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

    func sleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight] {
        let calendar = Calendar.current
        var nights: [SleepNight] = []
        var day = calendar.startOfDay(for: startDate)
        var index = 0
        while day <= endDate {
            let wake = calendar.date(bySettingHour: 6, minute: 35 + index % 15, second: 0, of: day) ?? day
            let totalHours = 6.2 + Double(noise(day: index, salt: 11)) * 1.6
            let start = wake.addingTimeInterval(-totalHours * 3600)
            let pattern: [(SleepStage, TimeInterval)] = [
                (.core, 48 * 60), (.deep, 35 * 60), (.core, 72 * 60), (.rem, 28 * 60),
                (.awake, 8 * 60), (.core, 84 * 60), (.deep, 24 * 60), (.core, 68 * 60),
                (.rem, 42 * 60), (.core, 55 * 60), (.rem, 35 * 60)
            ]
            let asleepBase = pattern.filter { $0.0.isAsleep }.reduce(0) { $0 + $1.1 }
            let scale = totalHours * 3600 / asleepBase
            var cursor = start
            let segments = pattern.map { stage, duration in
                let scaled = stage == .awake ? duration : duration * scale
                defer { cursor = cursor.addingTimeInterval(scaled) }
                return SleepSegment(start: cursor, end: cursor.addingTimeInterval(scaled), stage: stage)
            }
            nights.append(SleepNight(date: day, segments: segments))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }
        return nights
    }

    private func snapshot(for day: Date, index: Int) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: day,
            sleepHours: 6.5 + Double(noise(day: index, salt: 1)) * 2.0,
            hrvSDNN: 45 + Double(noise(day: index, salt: 2)) * 20,
            restingHeartRate: 58 + Double(noise(day: index, salt: 3)) * 6,
            steps: 5_000 + Double(noise(day: index, salt: 4)) * 6_000,
            activeEnergyKilocalories: 300 + Double(noise(day: index, salt: 5)) * 250,
            exerciseMinutes: 15 + Double(noise(day: index, salt: 6)) * 30,
            walkingRunningDistanceMeters: 2_000 + Double(noise(day: index, salt: 9)) * 6_000,
            vo2Max: index.isMultiple(of: 7)
                ? 38 + Double(noise(day: index, salt: 10)) * 8
                : nil
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
