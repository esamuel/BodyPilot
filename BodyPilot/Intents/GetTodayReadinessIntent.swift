import AppIntents
import Foundation
import SwiftData

/// "How am I today?" — computes the Body Score through the same shared
/// pipeline the app uses and answers with a spoken summary.
struct GetTodayReadinessIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Readiness"
    static let description = IntentDescription(
        "Tells you your Body Score and what kind of training fits today."
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(BodyPilotModelContainer.shared)
        let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let checkIn = Self.todaysCheckIn(in: context)

        let snapshot = try await ReadinessService().snapshot(
            preferences: ReadinessPreferences(profile: profile),
            feeling: checkIn?.feeling,
            soreness: checkIn?.soreness ?? []
        )
        let score = snapshot.score
        let recommendation = snapshot.recommendation
        let dialog = IntentDialog(
            "Your Body Score is \(score.score) — \(String(localized: score.readiness.displayName)). Today fits \(recommendation.recommendedDuration.minMinutes) to \(recommendation.recommendedDuration.maxMinutes) minutes at \(String(localized: recommendation.intensity.displayName).lowercased()) intensity."
        )
        return .result(dialog: dialog)
    }

    @MainActor
    static func todaysCheckIn(in context: ModelContext) -> CheckIn? {
        let checkIns = (try? context.fetch(
            FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
        return checkIns.first { Calendar.current.isDateInToday($0.date) }
    }
}
