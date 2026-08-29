import Foundation

/// Canned explainer for previews — shows the coach section without the model.
struct PreviewInsightExplainer: InsightExplaining {
    func explain(_ context: InsightContext) async throws -> String {
        String(localized: "You're trending a little above your usual — a normal training day fits well. Nice, steady rhythm this week.")
    }
}

/// Synthetic snapshots for SwiftUI previews. Never real health data.
extension InsightSnapshot {
    static var previewSleep: InsightSnapshot {
        let today = Calendar.current.startOfDay(for: .now)
        let pattern = (0..<7).reversed().compactMap { offset -> DatedValue? in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DatedValue(date: day, value: [7.2, 6.8, 7.5, 6.9, 7.1, 6.4, 7.7][offset % 7])
        }
        return InsightSnapshot(
            kind: .sleep,
            status: .excellent,
            statusLabel: String(localized: "Restorative night"),
            primaryValueText: "7h 42m",
            summary: String(localized: "You slept 28 minutes longer than your recent average and your overnight pattern was close to normal. Your recovery signals support a normal training day."),
            facts: [
                ExplanationFact(title: String(localized: "Last night"), detail: String(localized: "You slept 7h 42m.")),
                ExplanationFact(title: String(localized: "Vs your 28-day average"), detail: String(localized: "28 minutes more than your average of 7h 14m.")),
            ],
            comparisons: [
                BaselineComparison(
                    label: String(localized: "Sleep"),
                    todayText: "7h 42m",
                    typicalText: String(localized: "Usually 6h 50m–7h 40m"),
                    sevenDayTrend: .up
                ),
            ],
            trend: .up,
            pattern: pattern,
            action: SuggestedAction(title: String(localized: "Start recommended workout"), activity: nil, timeLimitMinutes: nil),
            confidence: 0.9,
            generatedAt: .now
        )
    }

    static var previewMovement: InsightSnapshot {
        InsightSnapshot(
            kind: .movement,
            status: .steady,
            statusLabel: String(localized: "Room to move"),
            primaryValueText: String(localized: "1,600 steps"),
            summary: String(localized: "You're below your usual full-day movement so far. A short walk would bring you close to your normal pattern."),
            facts: [
                ExplanationFact(title: String(localized: "Steps so far"), detail: String(localized: "1,600 steps today.")),
                ExplanationFact(title: String(localized: "Your usual day"), detail: String(localized: "You typically take about 7,800 steps in a full day.")),
            ],
            comparisons: [
                BaselineComparison(
                    label: String(localized: "Steps"),
                    todayText: "1,600",
                    typicalText: String(localized: "Usually 6,400–9,200"),
                    sevenDayTrend: .steady
                ),
            ],
            trend: .steady,
            pattern: [],
            action: SuggestedAction(title: String(localized: "Take a 20-minute walk"), activity: .walking, timeLimitMinutes: 20),
            confidence: 0.9,
            generatedAt: .now
        )
    }

    static var previewRecovery: InsightSnapshot {
        InsightSnapshot(
            kind: .recovery,
            status: .steady,
            statusLabel: String(localized: "Go easier today"),
            primaryValueText: String(localized: "Score 58"),
            summary: String(localized: "Some recovery signals are below your norm. Today is a good day for moderate activity rather than a hard session."),
            facts: [
                ExplanationFact(title: String(localized: "Sleep"), detail: String(localized: "You slept less than usual.")),
                ExplanationFact(title: String(localized: "HRV"), detail: String(localized: "Slightly below your normal range.")),
            ],
            comparisons: [
                BaselineComparison(
                    label: String(localized: "HRV"),
                    todayText: "-8%",
                    typicalText: String(localized: "vs your 28-day norm"),
                    sevenDayTrend: .down
                ),
                BaselineComparison(
                    label: String(localized: "Resting HR"),
                    todayText: "+2 bpm",
                    typicalText: String(localized: "vs your 28-day norm"),
                    sevenDayTrend: .steady
                ),
            ],
            trend: .down,
            pattern: [],
            action: SuggestedAction(title: String(localized: "Choose an easy session"), activity: nil, timeLimitMinutes: 30),
            confidence: 0.8,
            generatedAt: .now
        )
    }
}
