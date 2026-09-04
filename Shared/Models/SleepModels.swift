import Foundation

enum SleepStage: String, Codable, CaseIterable, Sendable {
    case awake
    case rem
    case core
    case deep
    case asleepUnspecified

    nonisolated var isAsleep: Bool { self != .awake }
}

struct SleepSegment: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let stage: SleepStage

    nonisolated init(id: UUID = UUID(), start: Date, end: Date, stage: SleepStage) {
        self.id = id
        self.start = start
        self.end = end
        self.stage = stage
    }

    nonisolated var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct SleepNight: Codable, Hashable, Identifiable, Sendable {
    /// The local calendar day on which this sleep session ended.
    let date: Date
    let segments: [SleepSegment]

    nonisolated var id: Date { date }

    nonisolated var asleepSegments: [SleepSegment] {
        segments.filter { $0.stage.isAsleep }
    }

    nonisolated var totalSleep: TimeInterval {
        asleepSegments.reduce(0) { $0 + $1.duration }
    }

    nonisolated var restorativeSleep: TimeInterval {
        duration(for: .rem) + duration(for: .deep)
    }

    nonisolated var awakeDuration: TimeInterval { duration(for: .awake) }
    nonisolated var fellAsleepAt: Date? { asleepSegments.map(\.start).min() }
    nonisolated var wokeUpAt: Date? { asleepSegments.map(\.end).max() }

    nonisolated func duration(for stage: SleepStage) -> TimeInterval {
        segments.lazy.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }
}
