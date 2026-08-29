import AppIntents

/// App Shortcuts per PRD 5.4. Phrases are a published contract — add new ones,
/// never rename or remove shipped ones.
struct BodyPilotShortcuts: AppShortcutsProvider {
    nonisolated static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayReadinessIntent(),
            phrases: [
                "How am I today in \(.applicationName)",
                "Get my readiness in \(.applicationName)",
                "What's my Body Score in \(.applicationName)",
            ],
            shortTitle: "Today's Readiness",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: LogFeelingIntent(),
            phrases: [
                "Log how I feel in \(.applicationName)",
                "Check in with \(.applicationName)",
            ],
            shortTitle: "Log Feeling",
            systemImageName: "face.smiling"
        )
        AppShortcut(
            intent: CreateQuickWorkoutIntent(),
            phrases: [
                "Give me a quick workout in \(.applicationName)",
                "Create a workout in \(.applicationName)",
            ],
            shortTitle: "Quick Workout",
            systemImageName: "figure.run"
        )
    }
}
