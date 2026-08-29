import Foundation
import SwiftData

/// A daily self-reported readiness check-in.
/// Influences recommendations but never overrides safety logic.
@Model
final class CheckIn {
    var date: Date
    var feeling: FeelingLevel
    var soreness: [SorenessArea]
    var note: String?

    init(
        date: Date = .now,
        feeling: FeelingLevel = .normal,
        soreness: [SorenessArea] = [],
        note: String? = nil
    ) {
        self.date = date
        self.feeling = feeling
        self.soreness = soreness
        self.note = note
    }
}
