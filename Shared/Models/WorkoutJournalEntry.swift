import Foundation
import SwiftData

/// App-owned metadata attached to a HealthKit workout by its stable UUID.
@Model
final class WorkoutJournalEntry {
    @Attribute(.unique) var workoutID: UUID
    var customName: String?
    var note: String
    var perceivedExertion: Int?
    var isFavorite: Bool
    var photoIdentifiers: [String]
    var updatedAt: Date

    init(
        workoutID: UUID,
        customName: String? = nil,
        note: String = "",
        perceivedExertion: Int? = nil,
        isFavorite: Bool = false,
        photoIdentifiers: [String] = [],
        updatedAt: Date = .now
    ) {
        self.workoutID = workoutID
        self.customName = customName
        self.note = note
        self.perceivedExertion = perceivedExertion
        self.isFavorite = isFavorite
        self.photoIdentifiers = photoIdentifiers
        self.updatedAt = updatedAt
    }
}
