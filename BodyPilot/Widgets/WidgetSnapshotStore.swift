import Foundation
import WidgetKit

/// Publishes a compact, derived snapshot for the home-screen widgets via the
/// shared App Group. Only display-ready strings and the score cross this
/// boundary — never raw HealthKit values or history.
///
/// Key names must stay in sync with the reader in
/// `BodyPilotWidgets/BodyPilotWidgets.swift`.
struct WidgetSnapshotStore {
    static let suiteName = "group.com.samueleskenasy.BodyPilot"

    private enum Key {
        static let bodyScore = "widget.bodyScore"
        static let readinessRaw = "widget.readinessRaw"
        static let readinessLabel = "widget.readinessLabel"
        static let recommendationText = "widget.recommendationText"
        static let movementValue = "widget.movementValue"
        static let movementStatus = "widget.movementStatus"
        static let updatedAt = "widget.updatedAt"
    }

    func publish(
        score: BodyScoreResult,
        recommendation: DailyRecommendation,
        insights: [InsightSnapshot]
    ) {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else { return }

        defaults.set(score.score, forKey: Key.bodyScore)
        defaults.set(score.readiness.rawValue, forKey: Key.readinessRaw)
        defaults.set(String(localized: score.readiness.displayName), forKey: Key.readinessLabel)
        defaults.set(recommendationLine(recommendation), forKey: Key.recommendationText)

        if let movement = insights.first(where: { $0.kind == .movement }) {
            defaults.set(movement.primaryValueText, forKey: Key.movementValue)
            defaults.set(movement.statusLabel, forKey: Key.movementStatus)
        }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Key.updatedAt)

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func recommendationLine(_ recommendation: DailyRecommendation) -> String {
        let duration = "\(recommendation.recommendedDuration.minMinutes)–\(recommendation.recommendedDuration.maxMinutes) min"
        return "\(duration) · \(String(localized: recommendation.intensity.displayName))"
    }
}
