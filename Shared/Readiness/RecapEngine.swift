import Foundation

enum RecapPeriod: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case week = 7
    case month = 30

    var id: Int { rawValue }
}

struct RecapSummary: Identifiable, Sendable, Equatable {
    var id: RecapPeriod { period }

    let period: RecapPeriod
    let activeDays: Int
    let workoutCount: Int
    let currentLoad: Double
    let previousLoad: Double
    let distanceMeters: Double
    let energyKilocalories: Double
    let photoCount: Int

    var loadChangeFraction: Double? {
        guard previousLoad > 0 else { return nil }
        return (currentLoad - previousLoad) / previousLoad
    }
}

struct RecapEngine: Sendable {
    let loadEngine: LoadEngine
    let calendar: Calendar

    init(loadEngine: LoadEngine = LoadEngine(), calendar: Calendar = .current) {
        self.loadEngine = loadEngine
        self.calendar = calendar
    }

    func summaries(
        snapshots: [DailyHealthSnapshot],
        workouts: [WorkoutSummary],
        journalEntries: [WorkoutJournalEntry],
        asOf date: Date
    ) -> [RecapSummary] {
        RecapPeriod.allCases.compactMap {
            summary(
                period: $0,
                snapshots: snapshots,
                workouts: workouts,
                journalEntries: journalEntries,
                asOf: date
            )
        }
    }

    private func summary(
        period: RecapPeriod,
        snapshots: [DailyHealthSnapshot],
        workouts: [WorkoutSummary],
        journalEntries: [WorkoutJournalEntry],
        asOf date: Date
    ) -> RecapSummary? {
        guard let currentStart = calendar.date(byAdding: .day, value: -period.rawValue, to: date),
              let previousStart = calendar.date(byAdding: .day, value: -2 * period.rawValue, to: date) else {
            return nil
        }
        let currentWorkouts = workouts.filter { $0.start >= currentStart && $0.start <= date }
        let previousWorkouts = workouts.filter { $0.start >= previousStart && $0.start < currentStart }
        let currentSnapshots = snapshots.filter { $0.date >= currentStart && $0.date <= date }
        let currentIDs = Set(currentWorkouts.map(\.id))

        return RecapSummary(
            period: period,
            activeDays: currentSnapshots.count { ($0.exerciseMinutes ?? 0) >= 10 },
            workoutCount: currentWorkouts.count,
            currentLoad: currentWorkouts.reduce(0) {
                $0 + loadEngine.workoutLoad(for: $1)
            },
            previousLoad: previousWorkouts.reduce(0) {
                $0 + loadEngine.workoutLoad(for: $1)
            },
            distanceMeters: currentSnapshots.reduce(0) {
                $0 + ($1.walkingRunningDistanceMeters ?? 0)
            },
            energyKilocalories: currentWorkouts.reduce(0) {
                $0 + ($1.totalEnergyKilocalories ?? 0)
            },
            photoCount: journalEntries
                .filter { currentIDs.contains($0.workoutID) }
                .reduce(0) { $0 + $1.photoIdentifiers.count }
        )
    }
}
