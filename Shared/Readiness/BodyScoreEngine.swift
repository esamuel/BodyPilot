import Foundation

/// Everything the Body Score engine needs — all values are derived, deterministic inputs.
struct BodyScoreInput: Sendable {
    let deltas: BaselineDeltas
    let recentLoad: TrainingLoad?
    /// 0–1 measure of how consistently the user balances activity and rest.
    let recoveryConsistency: Double?
    let feeling: FeelingLevel?
    let date: Date
}

/// Deterministic Body Score calculation per PRD 7.3.
/// AI never computes or overrides this score.
struct BodyScoreEngine: Sendable {
    let weights: BodyScoreWeights

    init(weights: BodyScoreWeights = .default) {
        self.weights = weights
    }

    func computeScore(from input: BodyScoreInput) -> BodyScoreResult {
        let normalizedValues: [(kind: ScoreComponentKind, value: Double?)] = [
            (.sleep, normalized(relativeDelta: input.deltas.sleepDelta)),
            (.hrv, normalized(relativeDelta: input.deltas.hrvDelta)),
            (.restingHeartRate, normalizedRestingHR(input.deltas.restingHRDeltaBPM)),
            (.recentLoad, normalizedLoad(input.recentLoad)),
            (.recoveryHistory, input.recoveryConsistency.map(clamped)),
            (.subjectiveFeeling, normalizedFeeling(input.feeling)),
        ]
        let components = normalizedValues.map { kind, value in
            ScoreComponent(kind: kind, weight: weights.weight(for: kind), normalizedValue: value)
        }

        let available = components.filter { $0.normalizedValue != nil }
        let availableWeight = available.reduce(0) { $0 + $1.weight }
        let score: Int
        if availableWeight > 0 {
            let weightedSum = available.reduce(0.0) { $0 + $1.weight * ($1.normalizedValue ?? 0) }
            score = Int((weightedSum / availableWeight * 100).rounded())
        } else {
            // Nothing is known: a neutral score with zero confidence, never a scary one.
            score = 50
        }
        let confidence = min(availableWeight, 1)

        return BodyScoreResult(
            score: score,
            confidence: confidence,
            readiness: ReadinessLevel(bodyScore: score),
            components: components,
            explanationFacts: facts(for: input, confidence: confidence),
            computedAt: input.date
        )
    }

    // MARK: - Normalization (all values clamped to 0…1)

    /// Relative deltas (sleep, HRV): on-baseline is 1.0; a 25% drop scores 0.5.
    private func normalized(relativeDelta: Double?) -> Double? {
        relativeDelta.map { clamped(1 + 2 * $0) }
    }

    /// Resting HR: each BPM above baseline costs 0.1; below baseline is fine.
    private func normalizedRestingHR(_ deltaBPM: Double?) -> Double? {
        deltaBPM.map { clamped(1 - $0 / 10) }
    }

    private func normalizedLoad(_ load: TrainingLoad?) -> Double? {
        switch load {
        case .rest: 1.0
        case .light: 0.9
        case .moderate: 0.75
        case .heavy: 0.5
        case nil: nil
        }
    }

    private func normalizedFeeling(_ feeling: FeelingLevel?) -> Double? {
        switch feeling {
        case .veryTired: 0.0
        case .tired: 0.35
        case .normal: 0.7
        case .good: 0.9
        case .excellent: 1.0
        case nil: nil
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    // MARK: - Explanation

    private func facts(for input: BodyScoreInput, confidence: Double) -> [ExplanationFact] {
        var facts: [ExplanationFact] = []

        if let sleepDelta = input.deltas.sleepDelta {
            facts.append(deltaFact(title: "Sleep", delta: sleepDelta, subject: String(localized: "You slept")))
        }
        if let hrvDelta = input.deltas.hrvDelta {
            facts.append(deltaFact(title: "HRV", delta: hrvDelta, subject: String(localized: "Your heart-rate variability is")))
        }
        if let restingHRDelta = input.deltas.restingHRDeltaBPM {
            let bpm = Int(abs(restingHRDelta).rounded())
            let detail: String = if abs(restingHRDelta) < 1.5 {
                String(localized: "Your resting heart rate is in its normal range.")
            } else if restingHRDelta > 0 {
                String(localized: "Your resting heart rate is \(bpm) BPM above your baseline.")
            } else {
                String(localized: "Your resting heart rate is \(bpm) BPM below your baseline.")
            }
            facts.append(ExplanationFact(title: String(localized: "Resting heart rate"), detail: detail))
        }
        if let load = input.recentLoad {
            let detail: String = switch load {
            case .rest: String(localized: "You haven't trained recently, so you're well rested.")
            case .light: String(localized: "Your recent training load is light.")
            case .moderate: String(localized: "Your recent training load is moderate.")
            case .heavy: String(localized: "Your recent training load is heavy — recovery matters today.")
            }
            facts.append(ExplanationFact(title: String(localized: "Training load"), detail: detail))
        }
        if let feeling = input.feeling {
            facts.append(ExplanationFact(
                title: String(localized: "Check-in"),
                detail: String(localized: "You reported feeling \(String(localized: feeling.factName)).")
            ))
        }
        if confidence < 0.7 {
            facts.append(ExplanationFact(
                title: String(localized: "Confidence"),
                detail: String(localized: "Some signals are missing, so today's score is less certain.")
            ))
        }
        return facts
    }

    private func deltaFact(title: LocalizedStringResource, delta: Double, subject: String) -> ExplanationFact {
        let percent = Int((abs(delta) * 100).rounded())
        let detail: String = if abs(delta) < 0.05 {
            String(localized: "\(subject) close to your normal range.")
        } else if delta > 0 {
            String(localized: "\(subject) \(percent)% above your usual.")
        } else {
            String(localized: "\(subject) \(percent)% below your usual.")
        }
        return ExplanationFact(title: String(localized: title), detail: detail)
    }
}

private extension FeelingLevel {
    var factName: LocalizedStringResource {
        switch self {
        case .veryTired: "very tired"
        case .tired: "tired"
        case .normal: "normal"
        case .good: "good"
        case .excellent: "excellent"
        }
    }
}
