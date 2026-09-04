import Foundation

enum CorridorState: String, Codable, CaseIterable, Sendable {
    case inside
    case above
    case below
}

enum CorridorWindow: Int, CaseIterable, Identifiable, Sendable {
    case day = 1
    case tenDays = 10
    case thirtyDays = 30

    var id: Int { rawValue }
}

struct CorridorDay: Codable, Hashable, Identifiable, Sendable {
    var id: Date { date }

    let date: Date
    let lowerBound: Double
    let upperBound: Double
    let load: Double
    let state: CorridorState
    let isRestRecommended: Bool
}

struct ActivityCorridor: Sendable, Equatable {
    let days: [CorridorDay]
    let confidence: Double
    let isPaused: Bool

    var today: CorridorDay? {
        days.last
    }
}

enum DailySuggestion: String, Codable, CaseIterable, Sendable {
    case rest
    case activeRecovery
    case light
    case moderate
    case hard
}

struct StreakResult: Sendable, Equatable {
    let count: Int
    let isFrozen: Bool
    let consecutiveAboveDays: Int
}
