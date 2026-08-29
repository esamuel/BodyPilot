import AppIntents
import Foundation
import SwiftData

/// "Log how I feel" — records a daily check-in through the same SwiftData
/// store the app uses.
struct LogFeelingIntent: AppIntent {
    static let title: LocalizedStringResource = "Log How I Feel"
    static let description = IntentDescription(
        "Records your daily readiness check-in."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Feeling")
    var feeling: FeelingLevel

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Log that I'm feeling \(\.$feeling)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(BodyPilotModelContainer.shared)
        context.insert(CheckIn(feeling: feeling))
        try context.save()
        return .result(
            dialog: IntentDialog(
                "Logged — feeling \(String(localized: feeling.displayName).lowercased()) today. Your recommendation will adjust."
            )
        )
    }
}
