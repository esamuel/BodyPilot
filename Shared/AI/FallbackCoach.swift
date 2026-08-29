import Foundation

/// Deterministic, template-based coach used whenever on-device AI is
/// unavailable. Keeps the Coach tab useful offline per PRD 7.5.
struct FallbackCoach: CoachProviding {
    func respond(to request: CoachRequest) async throws -> CoachResponse {
        let lowered = request.message.lowercased()
        let context = request.context

        let text: String
        if lowered.contains("why") || lowered.contains("score") {
            text = scoreExplanation(for: context)
        } else if lowered.contains("minute") || lowered.contains("time") {
            text = timeAdvice(for: request)
        } else if lowered.contains("easier") || lowered.contains("easy") || lowered.contains("tired") {
            text = String(localized: """
                Let's keep it gentle today. Easy movement — a comfortable walk or light \
                stretching — still counts and helps you recover. Listening to your body \
                is part of training well.
                """)
        } else {
            text = readinessSummary(for: context)
        }
        return CoachResponse(text: text, source: .fallback)
    }

    private func scoreExplanation(for context: AIContext) -> String {
        var parts: [String] = [
            String(localized: "Your Body Score today is \(context.bodyScore) of 100.")
        ]
        if let sleepDelta = context.sleepDelta, abs(sleepDelta) >= 0.05 {
            parts.append(
                sleepDelta < 0
                    ? String(localized: "You slept \(CoachPromptFormatter.percentText(sleepDelta)) versus your usual, which lowers readiness.")
                    : String(localized: "You slept \(CoachPromptFormatter.percentText(sleepDelta)) versus your usual — that helps.")
            )
        }
        if let hrvDelta = context.hrvDelta, abs(hrvDelta) >= 0.05 {
            parts.append(String(localized: "Your heart-rate variability is \(CoachPromptFormatter.percentText(hrvDelta)) versus baseline."))
        }
        if let restingHRDelta = context.restingHRDeltaBPM, abs(restingHRDelta) >= 2 {
            parts.append(String(localized: "Resting heart rate is \(restingHRDelta > 0 ? "+" : "")\(restingHRDelta) BPM from baseline."))
        }
        parts.append(String(localized: "Recent training load is \(context.recentLoad.rawValue)."))
        return parts.joined(separator: " ")
    }

    private func timeAdvice(for request: CoachRequest) -> String {
        let maxMinutes = request.constraints.compactMap { constraint in
            if case .maxDuration(let minutes) = constraint { minutes } else { Int?.none }
        }.min()
        if let maxMinutes {
            return String(localized: """
                Short on time is fine — anything from 10 minutes counts. Today's plan \
                fits within \(maxMinutes) minutes, and you can regenerate a shorter \
                workout from the Today tab.
                """)
        }
        return String(localized: "Even 10–15 minutes of comfortable movement is worthwhile today.")
    }

    private func readinessSummary(for context: AIContext) -> String {
        let band = ReadinessLevel(bodyScore: context.bodyScore)
        let message: String = switch band {
        case .strong:
            String(localized: "Your signals look strong today — a solid session fits if you feel up for it.")
        case .ready:
            String(localized: "You're in good shape for your usual training today.")
        case .easy:
            String(localized: "Today leans toward comfortable, moderate activity rather than a hard push.")
        case .recover:
            String(localized: "Your body is asking for recovery — gentle movement will do the most good.")
        }
        return String(localized: "Your Body Score is \(context.bodyScore). ") + message
    }
}
