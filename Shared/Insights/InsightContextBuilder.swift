import Foundation

/// Builds the validated, privacy-preserving context an AI coach may receive
/// for insight wording. Only deterministic facts cross this boundary — never
/// raw HealthKit samples, and never anything the engine didn't already state.
struct InsightContextBuilder: Sendable {
    func context(for snapshot: InsightSnapshot) -> InsightContext {
        InsightContext(
            kind: snapshot.kind,
            status: snapshot.status,
            facts: snapshot.facts,
            baselineComparisons: snapshot.comparisons,
            safeActions: snapshot.action.map { [$0.title] } ?? [],
            confidence: snapshot.confidence
        )
    }
}
