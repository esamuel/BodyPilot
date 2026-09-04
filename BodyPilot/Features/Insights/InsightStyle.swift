import SwiftUI

/// Per-world presentation: names, accents, and icons for the V1 insight set.
/// Accent colors are the semantic secondary palette from the brand pack.
extension InsightKind {
    var displayName: LocalizedStringResource {
        switch self {
        case .sleep: "Sleep"
        case .movement: "Steps & Movement"
        case .recovery: "Recovery"
        case .heart: "Cardio"
        case .trainingLoad: "Training Load"
        case .strength: "Strength"
        case .mobilityBalance: "Mobility & Balance"
        case .workoutHistory: "Workout Journey"
        }
    }

    var accent: Color {
        switch self {
        case .sleep: .sleepViolet
        case .movement: .movementAmber
        case .recovery: .recoveryGreen
        case .heart: .heartCoral
        case .trainingLoad: .pilotBlue
        case .strength: .deepBlue
        case .mobilityBalance: .routeTeal
        case .workoutHistory: .routeTeal
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: "moon.stars.fill"
        case .movement: "figure.walk"
        case .recovery: "arrow.clockwise.heart.fill"
        case .heart: "heart.fill"
        case .trainingLoad: "chart.bar.fill"
        case .strength: "dumbbell.fill"
        case .mobilityBalance: "figure.flexibility"
        case .workoutHistory: "map.fill"
        }
    }
}

extension InsightStatus {
    /// Calm tints — low readiness is indigo, never an alarming red.
    var tint: Color {
        switch self {
        case .excellent: .green
        case .good: .routeTeal
        case .steady: .orange
        case .low: .indigo
        case .unknown: .secondary
        }
    }
}

extension TrendDirection {
    var systemImage: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .steady: "arrow.right"
        case .unknown: "minus"
        }
    }

    var accessibilityDescription: LocalizedStringResource {
        switch self {
        case .up: "Trending up"
        case .down: "Trending down"
        case .steady: "Steady"
        case .unknown: "No trend yet"
        }
    }
}
