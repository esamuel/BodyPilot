import Foundation

/// Deterministic CTA selection for insight pages. Actions are parameters for
/// WorkoutGenerator, so every suggestion still passes generator validation and
/// safety constraints before it can start.
struct InsightActionEngine: Sendable {
    /// Steps assumed per minute of easy walking when sizing a catch-up walk.
    private static let walkStepsPerMinute: Double = 100
    private static let walkMinutesRange = 10...20

    func action(for kind: InsightKind, readiness: ReadinessLevel?, movementGapSteps: Double? = nil) -> SuggestedAction? {
        switch kind {
        case .sleep:
            sleepAction(readiness: readiness)
        case .movement:
            movementAction(gapSteps: movementGapSteps)
        case .recovery:
            recoveryAction(readiness: readiness)
        case .trainingLoad, .workoutHistory:
            SuggestedAction(
                title: String(localized: "Start recommended session"),
                activity: nil,
                timeLimitMinutes: nil
            )
        case .heart, .strength, .mobilityBalance:
            nil
        }
    }

    private func sleepAction(readiness: ReadinessLevel?) -> SuggestedAction {
        switch readiness {
        case .recover, .easy:
            SuggestedAction(
                title: String(localized: "Take an easy recovery session"),
                activity: .recovery,
                timeLimitMinutes: 20
            )
        default:
            SuggestedAction(
                title: String(localized: "Start recommended workout"),
                activity: nil,
                timeLimitMinutes: nil
            )
        }
    }

    private func movementAction(gapSteps: Double?) -> SuggestedAction {
        guard let gapSteps, gapSteps > 0 else {
            return SuggestedAction(
                title: String(localized: "Take a 10-minute walk"),
                activity: .walking,
                timeLimitMinutes: 10
            )
        }
        let rawMinutes = Int((gapSteps / Self.walkStepsPerMinute).rounded())
        let minutes = min(max(rawMinutes, Self.walkMinutesRange.lowerBound), Self.walkMinutesRange.upperBound)
        return SuggestedAction(
            title: String(localized: "Take a \(minutes)-minute walk"),
            activity: .walking,
            timeLimitMinutes: minutes
        )
    }

    private func recoveryAction(readiness: ReadinessLevel?) -> SuggestedAction {
        switch readiness {
        case .strong, .ready:
            SuggestedAction(
                title: String(localized: "Start recommended workout"),
                activity: nil,
                timeLimitMinutes: nil
            )
        case .easy:
            SuggestedAction(
                title: String(localized: "Choose an easy session"),
                activity: nil,
                timeLimitMinutes: 30
            )
        case .recover, nil:
            SuggestedAction(
                title: String(localized: "Take a recovery session"),
                activity: .recovery,
                timeLimitMinutes: 20
            )
        }
    }
}
