import Foundation

/// Everything the InsightEngine needs for one computation pass.
struct InsightInput: Sendable {
    let snapshots: [DailyHealthSnapshot]
    let workouts: [WorkoutSummary]
    /// Latest readiness pipeline output; nil while the score is unavailable.
    let score: BodyScoreResult?
    let deltas: BaselineDeltas?
    let recentLoad: TrainingLoad?
    let feeling: FeelingLevel?
    let date: Date
}

/// Deterministic builder of Body Insight snapshots. All classification is
/// relative to the user's personal baseline; the AI never calculates any of this.
struct InsightEngine: Sendable {
    private let baselineEngine: BaselineEngine
    private let actionEngine: InsightActionEngine
    private let calendar: Calendar

    /// Days of history shown in the pattern chart.
    private static let patternDays = 7
    /// Samples that count as a fully trustworthy baseline for confidence.
    private static let fullConfidenceSamples = 14

    init(
        baselineEngine: BaselineEngine = BaselineEngine(),
        actionEngine: InsightActionEngine = InsightActionEngine(),
        calendar: Calendar = .current
    ) {
        self.baselineEngine = baselineEngine
        self.actionEngine = actionEngine
        self.calendar = calendar
    }

    /// V1 insight set in hub display order.
    func insights(for input: InsightInput) -> [InsightSnapshot] {
        [
            sleepInsight(input),
            movementInsight(input),
            recoveryInsight(input),
            trainingLoadInsight(input),
            journeyInsight(input),
        ]
    }

    // MARK: - Sleep

    private func sleepInsight(_ input: InsightInput) -> InsightSnapshot {
        let series = dailySeries(input.snapshots, \.sleepHours)
        let today = todayValue(in: series, date: input.date)
        let baseline = baselineEngine.baseline(for: series, window: .primary, asOf: input.date)
        let delta: Double? = {
            guard let today, let baseline else { return nil }
            return baselineEngine.relativeDelta(current: today, baseline: baseline)
        }()

        let (status, label): (InsightStatus, String) = switch delta {
        case .some(let d) where d >= 0.05: (.excellent, String(localized: "Restorative night"))
        case .some(let d) where d >= -0.05: (.good, String(localized: "Close to your normal"))
        case .some(let d) where d >= -0.15: (.steady, String(localized: "A little under your usual"))
        case .some: (.low, String(localized: "Shorter than usual"))
        case nil: (.unknown, String(localized: "Building your sleep picture"))
        }

        var facts: [ExplanationFact] = []
        if let today {
            facts.append(ExplanationFact(
                title: String(localized: "Last night"),
                detail: String(localized: "You slept \(hoursText(today)).")
            ))
        }
        if let today, let baseline {
            let diffMinutes = Int(((today - baseline.mean) * 60).rounded())
            facts.append(ExplanationFact(
                title: String(localized: "Vs your 28-day average"),
                detail: diffMinutes >= 0
                    ? String(localized: "\(diffMinutes) minutes more than your average of \(hoursText(baseline.mean)).")
                    : String(localized: "\(-diffMinutes) minutes less than your average of \(hoursText(baseline.mean)).")
            ))
        }

        let summary: String = switch (today, delta) {
        case (.some, .some(let d)) where d >= -0.05:
            String(localized: "Last night was in line with your usual sleep. Your recovery signals support a normal training day.")
        case (.some, .some):
            String(localized: "You slept less than your recent norm. A gentler session today can help you stay consistent without adding strain.")
        case (.some, nil):
            String(localized: "Sleep was recorded last night. As more nights build up, BodyPilot will compare each one with your personal norm.")
        default:
            String(localized: "No sleep data was found for last night. Wearing your watch to sleep helps BodyPilot understand your recovery.")
        }

        return InsightSnapshot(
            kind: .sleep,
            status: status,
            statusLabel: label,
            primaryValueText: today.map(hoursText) ?? "—",
            summary: summary,
            facts: facts,
            comparisons: comparison(
                label: String(localized: "Sleep"),
                today: today.map(hoursText),
                baseline: baseline,
                series: series,
                asOf: input.date,
                format: hoursText
            ),
            trend: trend(series: series, asOf: input.date),
            pattern: patternSeries(series, asOf: input.date),
            action: actionEngine.action(for: .sleep, readiness: input.score?.readiness),
            confidence: baselineConfidence(baseline),
            generatedAt: input.date
        )
    }

    // MARK: - Steps & Movement

    private func movementInsight(_ input: InsightInput) -> InsightSnapshot {
        let series = dailySeries(input.snapshots, \.steps)
        let today = todayValue(in: series, date: input.date)
        let baseline = baselineEngine.baseline(for: series, window: .primary, asOf: input.date)
        let ratio: Double? = {
            guard let today, let baseline, baseline.mean > 0 else { return nil }
            return today / baseline.mean
        }()

        let (status, label): (InsightStatus, String) = switch ratio {
        case .some(let r) where r >= 1.0: (.excellent, String(localized: "Ahead of your usual"))
        case .some(let r) where r >= 0.7: (.good, String(localized: "On track for today"))
        case .some(let r) where r >= 0.4: (.steady, String(localized: "Room to move"))
        case .some: (.low, String(localized: "Quieter than usual"))
        case nil: (.unknown, String(localized: "Learning your movement pattern"))
        }

        let gap: Double? = {
            guard let today, let baseline else { return nil }
            return max(baseline.mean - today, 0)
        }()

        var facts: [ExplanationFact] = []
        if let today {
            facts.append(ExplanationFact(
                title: String(localized: "Steps so far"),
                detail: String(localized: "\(stepsText(today)) steps today.")
            ))
        }
        if let baseline {
            facts.append(ExplanationFact(
                title: String(localized: "Your usual day"),
                detail: String(localized: "You typically take about \(stepsText(baseline.mean)) steps in a full day.")
            ))
        }

        let summary: String = switch (gap, ratio) {
        case (.some(let g), .some) where g <= 0:
            String(localized: "You've already matched your usual full-day movement. Nice, sustainable rhythm.")
        case (.some, .some(let r)) where r >= 0.7:
            String(localized: "Your movement is close to your personal pattern for a full day. Keeping this rhythm supports your recovery and energy.")
        case (.some, .some):
            String(localized: "You're below your usual full-day movement so far. A short walk would bring you close to your normal pattern.")
        default:
            String(localized: "As BodyPilot learns your typical days, this page will compare your movement with your own pattern — not a generic step goal.")
        }

        return InsightSnapshot(
            kind: .movement,
            status: status,
            statusLabel: label,
            primaryValueText: today.map { String(localized: "\(stepsText($0)) steps") } ?? "—",
            summary: summary,
            facts: facts,
            comparisons: comparison(
                label: String(localized: "Steps"),
                today: today.map(stepsText),
                baseline: baseline,
                series: series,
                asOf: input.date,
                format: stepsText
            ),
            trend: trend(series: series, asOf: input.date),
            pattern: patternSeries(series, asOf: input.date),
            action: actionEngine.action(for: .movement, readiness: input.score?.readiness, movementGapSteps: gap),
            confidence: baselineConfidence(baseline),
            generatedAt: input.date
        )
    }

    // MARK: - Recovery

    private func recoveryInsight(_ input: InsightInput) -> InsightSnapshot {
        let readiness = input.score?.readiness

        let (status, label): (InsightStatus, String) = switch readiness {
        case .strong: (.excellent, String(localized: "Recovered and ready"))
        case .ready: (.good, String(localized: "Ready for a normal day"))
        case .easy: (.steady, String(localized: "Go easier today"))
        case .recover: (.low, String(localized: "Prioritize recovery"))
        case nil: (.unknown, String(localized: "Waiting for your Body Score"))
        }

        var facts: [ExplanationFact] = input.score.map { Array($0.explanationFacts.prefix(4)) } ?? []
        if let feeling = input.feeling {
            facts.append(ExplanationFact(
                title: String(localized: "Your check-in"),
                detail: String(localized: "You reported feeling \(String(localized: feeling.displayName)).")
            ))
        }

        var comparisons: [BaselineComparison] = []
        if let hrvDelta = input.deltas?.hrvDelta {
            comparisons.append(BaselineComparison(
                label: String(localized: "HRV"),
                todayText: percentText(hrvDelta),
                typicalText: String(localized: "vs your 28-day norm"),
                sevenDayTrend: hrvDelta > 0.05 ? .up : hrvDelta < -0.05 ? .down : .steady
            ))
        }
        if let hrDelta = input.deltas?.restingHRDeltaBPM {
            comparisons.append(BaselineComparison(
                label: String(localized: "Resting HR"),
                todayText: String(localized: "\(hrDelta >= 0 ? "+" : "")\(Int(hrDelta.rounded())) bpm"),
                typicalText: String(localized: "vs your 28-day norm"),
                sevenDayTrend: hrDelta > 2 ? .up : hrDelta < -2 ? .down : .steady
            ))
        }

        let summary: String = switch readiness {
        case .strong, .ready:
            String(localized: "Your recovery signals are close to or better than your personal norm. Today supports your planned training.")
        case .easy:
            String(localized: "Some recovery signals are below your norm. Today is a good day for moderate activity rather than a hard session.")
        case .recover:
            String(localized: "Your body is asking for recovery. An easy day now protects your consistency for the rest of the week.")
        case nil:
            String(localized: "Once your Body Score is calculated, this page explains exactly which signals raised or lowered your readiness.")
        }

        let hrvSeries = dailySeries(input.snapshots, \.hrvSDNN)
        return InsightSnapshot(
            kind: .recovery,
            status: status,
            statusLabel: label,
            primaryValueText: input.score.map { String(localized: "Score \($0.score)") } ?? "—",
            summary: summary,
            facts: facts,
            comparisons: comparisons,
            trend: trend(series: hrvSeries, asOf: input.date),
            pattern: patternSeries(hrvSeries, asOf: input.date),
            action: actionEngine.action(for: .recovery, readiness: readiness),
            confidence: input.score?.confidence ?? 0,
            generatedAt: input.date
        )
    }

    // MARK: - Training Load

    private func trainingLoadInsight(_ input: InsightInput) -> InsightSnapshot {
        let load = input.recentLoad
        let weekMinutes = workoutMinutes(input.workouts, days: 7, asOf: input.date)
        let monthMinutes = workoutMinutes(input.workouts, days: 28, asOf: input.date)
        let typicalWeek = monthMinutes / 4

        let (status, label): (InsightStatus, String) = switch load {
        case .rest: (.steady, String(localized: "Fully rested"))
        case .light: (.steady, String(localized: "Light training week"))
        case .moderate: (.good, String(localized: "Balanced training load"))
        case .heavy: (.low, String(localized: "Heavy load — recover well"))
        case nil: (.unknown, String(localized: "No recent workouts yet"))
        }

        let facts = [
            ExplanationFact(
                title: String(localized: "Last 7 days"),
                detail: String(localized: "\(Int(weekMinutes.rounded())) minutes of workouts.")
            ),
            ExplanationFact(
                title: String(localized: "Your typical week"),
                detail: String(localized: "About \(Int(typicalWeek.rounded())) minutes, based on the last 28 days.")
            ),
        ]

        let summary: String = switch load {
        case .heavy:
            String(localized: "You've trained more than usual this week. Balancing it with easier days is what turns that work into fitness.")
        case .moderate:
            String(localized: "Your training volume is in a sustainable range for you. This balance supports steady progress.")
        case .light, .rest:
            String(localized: "Your recent load is light, so your body has capacity for today's session if your recovery signals agree.")
        case nil:
            String(localized: "Once workouts are recorded, this page shows where you sit inside your own sustainable training range.")
        }

        let dailyMinutes = dailyWorkoutMinutes(input.workouts, days: Self.patternDays, asOf: input.date)
        return InsightSnapshot(
            kind: .trainingLoad,
            status: status,
            statusLabel: label,
            primaryValueText: String(localized: "\(Int(weekMinutes.rounded())) min"),
            summary: summary,
            facts: facts,
            comparisons: [
                BaselineComparison(
                    label: String(localized: "Weekly minutes"),
                    todayText: String(localized: "\(Int(weekMinutes.rounded())) min"),
                    typicalText: String(localized: "Usually about \(Int(typicalWeek.rounded())) min"),
                    sevenDayTrend: typicalWeek > 0
                        ? (weekMinutes > typicalWeek * 1.15 ? .up : weekMinutes < typicalWeek * 0.85 ? .down : .steady)
                        : .unknown
                ),
            ],
            trend: typicalWeek > 0
                ? (weekMinutes > typicalWeek * 1.15 ? .up : weekMinutes < typicalWeek * 0.85 ? .down : .steady)
                : .unknown,
            pattern: dailyMinutes,
            action: actionEngine.action(for: .trainingLoad, readiness: input.score?.readiness),
            confidence: input.workouts.isEmpty ? 0.3 : 0.9,
            generatedAt: input.date
        )
    }

    // MARK: - Workout Journey

    private func journeyInsight(_ input: InsightInput) -> InsightSnapshot {
        let monthWorkouts = recentWorkouts(input.workouts, days: 30, asOf: input.date)
        let count = monthWorkouts.count
        let minutes = monthWorkouts.reduce(0) { $0 + $1.durationMinutes }
        let activities = Set(monthWorkouts.compactMap(\.activity))

        let (status, label): (InsightStatus, String) = switch count {
        case 12...: (.excellent, String(localized: "A strong month of movement"))
        case 6...: (.good, String(localized: "Building real momentum"))
        case 1...: (.steady, String(localized: "Your journey is under way"))
        default: (.steady, String(localized: "Your journey starts here"))
        }

        var facts = [
            ExplanationFact(
                title: String(localized: "Last 30 days"),
                detail: String(localized: "\(count) workouts, \(Int(minutes.rounded())) total minutes.")
            ),
        ]
        if !activities.isEmpty {
            let names = activities
                .map { String(localized: $0.displayName) }
                .sorted()
                .formatted(.list(type: .and))
            facts.append(ExplanationFact(
                title: String(localized: "Activity mix"),
                detail: String(localized: "You've done \(names).")
            ))
        }

        let summary: String = count > 0
            ? String(localized: "Every workout is a step on your route. Consistency — not single hard days — is what moves your fitness forward.")
            : String(localized: "Your first workout starts the route. BodyPilot will map every session as a milestone on your journey.")

        return InsightSnapshot(
            kind: .workoutHistory,
            status: status,
            statusLabel: label,
            primaryValueText: String(localized: "\(count) workouts"),
            summary: summary,
            facts: facts,
            comparisons: [],
            trend: .unknown,
            pattern: dailyWorkoutMinutes(input.workouts, days: Self.patternDays, asOf: input.date),
            action: actionEngine.action(for: .workoutHistory, readiness: input.score?.readiness),
            confidence: count > 0 ? 1 : 0.3,
            generatedAt: input.date
        )
    }

    // MARK: - Shared helpers

    private func dailySeries(_ snapshots: [DailyHealthSnapshot], _ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> [DatedValue] {
        snapshots
            .compactMap { snapshot in
                snapshot[keyPath: keyPath].map { DatedValue(date: snapshot.date, value: $0) }
            }
            .sorted { $0.date < $1.date }
    }

    private func todayValue(in series: [DatedValue], date: Date) -> Double? {
        let today = calendar.startOfDay(for: date)
        return series.first { $0.date == today }?.value
    }

    private func patternSeries(_ series: [DatedValue], asOf date: Date) -> [DatedValue] {
        guard let start = calendar.date(byAdding: .day, value: -Self.patternDays, to: calendar.startOfDay(for: date)) else {
            return []
        }
        return series.filter { $0.date > start && $0.date <= date }
    }

    /// Compares the 7-day mean with the 28-day mean; ±5% counts as steady.
    private func trend(series: [DatedValue], asOf date: Date) -> TrendDirection {
        guard let short = baselineEngine.baseline(for: series, window: .short, asOf: date),
              let primary = baselineEngine.baseline(for: series, window: .primary, asOf: date),
              primary.mean > 0 else {
            return .unknown
        }
        let delta = (short.mean - primary.mean) / primary.mean
        if delta > 0.05 { return .up }
        if delta < -0.05 { return .down }
        return .steady
    }

    private func comparison(
        label: String,
        today: String?,
        baseline: MetricBaseline?,
        series: [DatedValue],
        asOf date: Date,
        format: (Double) -> String
    ) -> [BaselineComparison] {
        guard let baseline else { return [] }
        let low = max(baseline.mean - baseline.standardDeviation, 0)
        let high = baseline.mean + baseline.standardDeviation
        return [
            BaselineComparison(
                label: label,
                todayText: today ?? "—",
                typicalText: String(localized: "Usually \(format(low))–\(format(high))"),
                sevenDayTrend: trend(series: series, asOf: date)
            ),
        ]
    }

    private func baselineConfidence(_ baseline: MetricBaseline?) -> Double {
        guard let baseline else { return 0 }
        return min(Double(baseline.sampleCount) / Double(Self.fullConfidenceSamples), 1)
    }

    private func recentWorkouts(_ workouts: [WorkoutSummary], days: Int, asOf date: Date) -> [WorkoutSummary] {
        guard let start = calendar.date(byAdding: .day, value: -days, to: date) else { return [] }
        return workouts.filter { $0.start >= start && $0.start <= date }
    }

    private func workoutMinutes(_ workouts: [WorkoutSummary], days: Int, asOf date: Date) -> Double {
        recentWorkouts(workouts, days: days, asOf: date).reduce(0) { $0 + $1.durationMinutes }
    }

    /// One value per day (including zero-minute days) so the pattern chart shows rhythm.
    private func dailyWorkoutMinutes(_ workouts: [WorkoutSummary], days: Int, asOf date: Date) -> [DatedValue] {
        let today = calendar.startOfDay(for: date)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            let minutes = workouts
                .filter { $0.start >= day && $0.start < next }
                .reduce(0) { $0 + $1.durationMinutes }
            return DatedValue(date: day, value: minutes)
        }
    }

    private func hoursText(_ hours: Double) -> String {
        Duration.seconds(hours * 3600).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func stepsText(_ steps: Double) -> String {
        Int(steps.rounded()).formatted()
    }

    private func percentText(_ delta: Double) -> String {
        let percent = Int((delta * 100).rounded())
        return "\(percent >= 0 ? "+" : "")\(percent)%"
    }
}
