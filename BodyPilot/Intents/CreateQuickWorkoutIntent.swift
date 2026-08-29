import AppIntents
import Foundation
import SwiftData

/// "Give me a 20-minute workout" — generates a validated workout through the
/// same generator the app uses and saves it for the Workout tab.
struct CreateQuickWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Create a Quick Workout"
    static let description = IntentDescription(
        "Generates a workout that fits your readiness and available time."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Minutes", default: 20, inclusiveRange: (10, 90))
    var minutes: Int

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$minutes)-minute workout")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(BodyPilotModelContainer.shared)
        let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let checkIn = GetTodayReadinessIntent.todaysCheckIn(in: context)
        let preferences = ReadinessPreferences(profile: profile)

        // Resolve and generate first; the irreversible save happens last.
        let snapshot = try await ReadinessService().snapshot(
            preferences: preferences,
            feeling: checkIn?.feeling,
            soreness: checkIn?.soreness ?? []
        )
        let plan = try WorkoutGenerator().generateWorkout(
            for: WorkoutRequest(
                recommendation: snapshot.recommendation,
                goal: preferences.goal,
                equipment: preferences.equipment,
                timeLimitMinutes: minutes
            )
        )

        context.insert(GeneratedWorkout(plan: plan))
        try context.save()
        return .result(
            dialog: IntentDialog(
                "Created \(plan.title) with \(plan.steps.count) steps. It's waiting in the Workout tab."
            )
        )
    }
}
