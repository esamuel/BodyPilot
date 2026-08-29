import Foundation

/// Provider abstraction for AI-worded insight explanations (Section F of an
/// insight page). Implementations receive only a validated InsightContext —
/// never raw HealthKit data — and pages must work when no provider exists.
protocol InsightExplaining: Sendable {
    func explain(_ context: InsightContext) async throws -> String
}

/// Instructions and prompt rendering for insight explanations. The wording
/// model may only rephrase the deterministic facts it is given.
enum InsightExplainerPrompt {
    static let instructions = """
        You are the coach inside BodyPilot, a fitness and recovery app. \
        Your tone is calm, warm, encouraging, and never judgmental. \
        You will receive validated facts about one health/fitness dimension. \
        Rephrase them as one short, friendly explanation of what they mean for \
        the user's day. Use only the numbers and facts provided; never invent \
        data, causes, or medical claims. Never diagnose. Do not contradict the \
        stated status or suggested action. Keep it under 60 words.
        """

    static func prompt(for context: InsightContext) -> String {
        var lines: [String] = [
            "Insight: \(context.kind.rawValue)",
            "Status: \(context.status.rawValue)",
            "Data confidence: \(Int(context.confidence * 100))%",
            "Facts:",
        ]
        lines.append(contentsOf: context.facts.map { "- \($0.title): \($0.detail)" })
        if !context.baselineComparisons.isEmpty {
            lines.append("Personal baseline:")
            lines.append(contentsOf: context.baselineComparisons.map {
                "- \($0.label): today \($0.todayText), \($0.typicalText), 7-day trend \($0.sevenDayTrend.rawValue)"
            })
        }
        if !context.safeActions.isEmpty {
            lines.append("Suggested next step (do not change it): \(context.safeActions.joined(separator: "; "))")
        }
        return lines.joined(separator: "\n")
    }
}
