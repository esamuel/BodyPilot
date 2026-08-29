import Foundation

/// Builds the derived, privacy-preserving context the coach receives.
/// Values are rounded to coarse precision — raw HealthKit samples never
/// reach this layer, only baseline-relative deltas.
struct AIContextBuilder: Sendable {
    func makeContext(
        score: BodyScoreResult,
        deltas: BaselineDeltas,
        recentLoad: TrainingLoad,
        feeling: FeelingLevel?,
        goal: FitnessGoal,
        equipment: [EquipmentType],
        preferredActivities: [ActivityType],
        preferredWorkoutMinutes: Int
    ) -> AIContext {
        AIContext(
            bodyScore: score.score,
            confidence: rounded(score.confidence),
            sleepDelta: deltas.sleepDelta.map(rounded),
            hrvDelta: deltas.hrvDelta.map(rounded),
            restingHRDeltaBPM: deltas.restingHRDeltaBPM.map { Int($0.rounded()) },
            recentLoad: recentLoad,
            feeling: feeling ?? .normal,
            goal: goal,
            equipment: equipment,
            preferredActivities: preferredActivities,
            preferredWorkoutMinutes: preferredWorkoutMinutes
        )
    }

    /// Two decimal places — enough for coaching, too coarse to reconstruct raw data.
    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

/// Renders the derived context and constraints as text for prompts and
/// deterministic fallback responses.
enum CoachPromptFormatter {
    static func contextBlock(for context: AIContext, constraints: [WorkoutConstraint]) -> String {
        var lines: [String] = [
            "Context:",
            "- Body Score: \(context.bodyScore) of 100 (confidence \(Int(context.confidence * 100))%)",
            "- Recent training load: \(context.recentLoad.rawValue)",
            "- Reported feeling: \(context.feeling.rawValue)",
            "- Goal: \(context.goal.rawValue)",
            "- Equipment: \(context.equipment.map(\.rawValue).joined(separator: ", "))",
            "- Preferred activities: \(activityList(context.preferredActivities))",
            "- Preferred workout length: \(context.preferredWorkoutMinutes) minutes",
        ]
        if let sleepDelta = context.sleepDelta {
            lines.append("- Sleep vs. baseline: \(percentText(sleepDelta))")
        }
        if let hrvDelta = context.hrvDelta {
            lines.append("- HRV vs. baseline: \(percentText(hrvDelta))")
        }
        if let restingHRDelta = context.restingHRDeltaBPM {
            lines.append("- Resting HR vs. baseline: \(restingHRDelta >= 0 ? "+" : "")\(restingHRDelta) BPM")
        }
        if !constraints.isEmpty {
            lines.append("Constraints (must never be exceeded):")
            lines.append(contentsOf: constraints.map { "- \(describe($0))" })
        }
        return lines.joined(separator: "\n")
    }

    static func percentText(_ delta: Double) -> String {
        let percent = Int((delta * 100).rounded())
        return "\(percent >= 0 ? "+" : "")\(percent)%"
    }

    static func describe(_ constraint: WorkoutConstraint) -> String {
        switch constraint {
        case .maxDuration(let minutes):
            "maximum \(minutes) minutes"
        case .avoidHighIntensity:
            "no high-intensity work today"
        case .avoidSorenessArea(let area):
            "avoid loading the \(area.rawValue) area"
        case .equipmentLimit(let equipment):
            "equipment limited to: \(equipment.map(\.rawValue).joined(separator: ", "))"
        }
    }

    private static func activityList(_ activities: [ActivityType]) -> String {
        guard !activities.isEmpty else { return "none specified" }
        return activities.map(\.rawValue).joined(separator: ", ")
    }
}
