import Foundation
import SwiftData

/// Coaching preferences chosen during onboarding and adjustable in Settings.
@Model
final class CoachPreference {
    var tone: CoachTone
    var preferredWorkoutMinutes: Int
    /// Preferred workout days using Calendar weekday numbering (1 = Sunday … 7 = Saturday).
    var preferredWeekdays: [Int]

    init(
        tone: CoachTone = .supportive,
        preferredWorkoutMinutes: Int = 30,
        preferredWeekdays: [Int] = []
    ) {
        self.tone = tone
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
        self.preferredWeekdays = preferredWeekdays
    }
}
