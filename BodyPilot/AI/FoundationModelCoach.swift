import Foundation
import FoundationModels

enum FoundationModelCoachError: Error {
    case modelUnavailable(SystemLanguageModel.Availability)
}

extension FoundationModelCoachError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let availability):
            switch availability {
            case .available:
                String(localized: "On-device AI is available.")
            case .unavailable(.appleIntelligenceNotEnabled):
                String(localized: "Apple Intelligence is turned off in Settings.")
            case .unavailable(.deviceNotEligible):
                String(localized: "This device doesn't support Apple Intelligence.")
            case .unavailable(.modelNotReady):
                String(localized: "Apple Intelligence is still preparing its on-device model.")
            case .unavailable:
                String(localized: "On-device AI is unavailable.")
            }
        }
    }
}

/// CoachProviding backed by Apple's on-device Foundation Models.
/// Receives only derived context — never raw HealthKit history.
struct FoundationModelCoach: CoachProviding {
    func respond(to request: CoachRequest) async throws -> CoachResponse {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw FoundationModelCoachError.modelUnavailable(availability)
        }

        let session = LanguageModelSession(instructions: request.profile.instructions)
        let prompt = """
        \(CoachPromptFormatter.contextBlock(for: request.context, constraints: request.constraints))

        User message: \(request.message)
        """
        let response = try await session.respond(to: prompt)
        return CoachResponse(text: response.content, source: .onDeviceAI)
    }
}
