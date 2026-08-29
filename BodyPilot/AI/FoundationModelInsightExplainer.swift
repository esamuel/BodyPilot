import Foundation
import FoundationModels

/// InsightExplaining backed by Apple's on-device Foundation Models.
/// Receives only the validated InsightContext; throws when the model is
/// unavailable so pages can simply hide the coach section.
struct FoundationModelInsightExplainer: InsightExplaining {
    func explain(_ context: InsightContext) async throws -> String {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw FoundationModelCoachError.modelUnavailable(availability)
        }
        let session = LanguageModelSession(instructions: InsightExplainerPrompt.instructions)
        let response = try await session.respond(to: InsightExplainerPrompt.prompt(for: context))
        return response.content
    }
}
