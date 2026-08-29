import Foundation
import Observation

/// Loads the optional AI-worded explanation for one insight page.
/// The page renders fully without it; this only adds friendlier phrasing
/// of facts the deterministic engine already produced.
@MainActor
@Observable
final class InsightCoachModel {
    enum State {
        case idle
        case loading
        case ready(String)
        case unavailable
    }

    private(set) var state: State = .idle

    private let explainer: any InsightExplaining
    private let contextBuilder = InsightContextBuilder()

    init(explainer: any InsightExplaining = FoundationModelInsightExplainer()) {
        self.explainer = explainer
    }

    func load(for snapshot: InsightSnapshot) async {
        guard case .idle = state else { return }
        // Nothing meaningful to phrase until real data exists.
        guard snapshot.status != .unknown else {
            state = .unavailable
            return
        }
        state = .loading
        do {
            let text = try await explainer.explain(contextBuilder.context(for: snapshot))
            state = .ready(text)
        } catch {
            state = .unavailable
        }
    }
}
