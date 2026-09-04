import Foundation
import SwiftData

/// Central definition of the app-owned SwiftData schema, shared by iPhone and Watch.
enum BodyPilotModelContainer {
    static let schema = Schema([
        UserProfile.self,
        CheckIn.self,
        GeneratedWorkout.self,
        CoachPreference.self,
        ProgramEnrollment.self,
        LifeStatus.self,
        WorkoutJournalEntry.self,
    ])

    static func make(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Single container shared by the app and its App Intents so both see the same store.
    @MainActor static let shared: ModelContainer = {
        do {
            return try make()
        } catch {
            // The app cannot function without its persistence layer.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
