import Foundation

/// Orchestrates coaching: the deterministic safety gate always runs first,
/// then the primary (AI) provider, then the deterministic fallback.
/// The gate's verdict can never be bypassed by any provider.
struct CoachService: Sendable {
    private let primary: (any CoachProviding)?
    private let fallback: any CoachProviding
    private let safetyGate: SafetyGate

    init(
        primary: (any CoachProviding)?,
        fallback: any CoachProviding = FallbackCoach(),
        safetyGate: SafetyGate = SafetyGate()
    ) {
        self.primary = primary
        self.fallback = fallback
        self.safetyGate = safetyGate
    }

    func respond(to request: CoachRequest) async -> CoachResponse {
        if let safety = safetyGate.safetyResponse(for: request.message) {
            return safety
        }
        var primaryFailureReason: String?
        if let primary {
            do {
                return try await primary.respond(to: request)
            } catch {
                primaryFailureReason = error.localizedDescription
            }
        }
        if let response = try? await fallback.respond(to: request) {
            return CoachResponse(
                text: response.text,
                source: response.source,
                fallbackReason: primaryFailureReason
            )
        }
        return CoachResponse(
            text: String(localized: "I can't answer right now, but your daily recommendation on the Today tab is always available."),
            source: .fallback,
            fallbackReason: primaryFailureReason
        )
    }
}
