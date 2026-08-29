import Foundation

/// Deterministic symptom screening per PRD section 11. This runs before any
/// language model sees the message, and its verdict can never be bypassed by AI.
struct SafetyGate: Sendable {
    /// Phrases that indicate potentially serious symptoms. Matching is
    /// case-insensitive substring matching — deliberately conservative.
    static let redFlagPhrases: [String] = [
        "chest pain",
        "chest pressure",
        "pain in my chest",
        "shortness of breath",
        "can't breathe",
        "cannot breathe",
        "hard to breathe",
        "dizzy",
        "dizziness",
        "faint",
        "numb",
        "numbness",
        "palpitations",
        "heart is racing",
        "irregular heartbeat",
        "severe pain",
        "blurred vision",
        "confusion",
    ]

    /// Returns a conservative safety response when the message mentions a
    /// potentially serious symptom; nil when the message is safe to coach on.
    func safetyResponse(for message: String) -> CoachResponse? {
        let lowered = message.lowercased()
        guard Self.redFlagPhrases.contains(where: lowered.contains) else {
            return nil
        }
        return CoachResponse(
            text: String(localized: """
                Please stop exercising now. What you're describing deserves real medical \
                attention, and BodyPilot isn't able to assess symptoms. If it feels serious \
                or doesn't pass quickly, contact emergency services. Otherwise, please talk \
                to a doctor before your next workout. Your training can wait — you matter more.
                """),
            source: .safety
        )
    }
}
