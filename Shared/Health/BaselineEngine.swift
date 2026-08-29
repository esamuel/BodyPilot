import Foundation

/// Rolling-window definitions per PRD 7.3. The single place to tune baseline behavior.
struct BaselineConfiguration: Sendable {
    let shortWindowDays: Int
    let primaryWindowDays: Int
    let trendWindowDays: Int
    let shortWindowMinimumSamples: Int
    let primaryWindowMinimumSamples: Int
    let trendWindowMinimumSamples: Int

    static let `default` = BaselineConfiguration(
        shortWindowDays: 7,
        primaryWindowDays: 28,
        trendWindowDays: 90,
        shortWindowMinimumSamples: 4,
        primaryWindowMinimumSamples: 14,
        trendWindowMinimumSamples: 30
    )

    func days(for window: BaselineWindow) -> Int {
        switch window {
        case .short: shortWindowDays
        case .primary: primaryWindowDays
        case .trend: trendWindowDays
        }
    }

    func minimumSamples(for window: BaselineWindow) -> Int {
        switch window {
        case .short: shortWindowMinimumSamples
        case .primary: primaryWindowMinimumSamples
        case .trend: trendWindowMinimumSamples
        }
    }
}

enum BaselineWindow: CaseIterable, Sendable {
    case short
    case primary
    case trend
}

/// Personal rolling baseline for one metric.
struct MetricBaseline: Hashable, Sendable {
    let mean: Double
    let standardDeviation: Double
    let sampleCount: Int
    let window: BaselineWindow
}

/// Today's signals relative to the personal baseline. Nil means insufficient data.
struct BaselineDeltas: Hashable, Sendable {
    /// Relative sleep delta, e.g. -0.08 for 8% below the personal norm.
    let sleepDelta: Double?
    /// Relative HRV delta.
    let hrvDelta: Double?
    /// Absolute resting-heart-rate delta in BPM (positive = elevated).
    let restingHRDeltaBPM: Double?
}

/// Deterministic rolling-baseline statistics. Personal baselines beat population
/// cutoffs — every comparison here is against the user's own history.
struct BaselineEngine: Sendable {
    let configuration: BaselineConfiguration
    let calendar: Calendar

    init(configuration: BaselineConfiguration = .default, calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    /// Computes the baseline for one metric over the given window ending the day
    /// before `date` — today's value is never part of its own baseline.
    /// Returns nil when the window holds fewer than the configured minimum samples.
    func baseline(for values: [DatedValue], window: BaselineWindow, asOf date: Date) -> MetricBaseline? {
        let cutoff = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .day, value: -configuration.days(for: window), to: cutoff) else {
            return nil
        }

        let samples = values
            .filter { $0.date >= windowStart && $0.date < cutoff }
            .map(\.value)
        guard samples.count >= configuration.minimumSamples(for: window) else { return nil }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
        return MetricBaseline(
            mean: mean,
            standardDeviation: variance.squareRoot(),
            sampleCount: samples.count,
            window: window
        )
    }

    /// Relative delta of the current value against a baseline; nil when the
    /// baseline mean is not positive (relative comparison would be meaningless).
    func relativeDelta(current: Double, baseline: MetricBaseline) -> Double? {
        guard baseline.mean > 0 else { return nil }
        return (current - baseline.mean) / baseline.mean
    }

    /// Today's sleep/HRV/resting-HR deltas against the primary-window baseline.
    func deltas(for snapshots: [DailyHealthSnapshot], asOf date: Date) -> BaselineDeltas {
        let today = calendar.startOfDay(for: date)
        let current = snapshots.first { $0.date == today }

        func series(_ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> [DatedValue] {
            snapshots.compactMap { snapshot in
                snapshot[keyPath: keyPath].map { DatedValue(date: snapshot.date, value: $0) }
            }
        }

        func relative(_ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> Double? {
            guard let value = current?[keyPath: keyPath],
                  let baseline = baseline(for: series(keyPath), window: .primary, asOf: date) else {
                return nil
            }
            return relativeDelta(current: value, baseline: baseline)
        }

        let restingHRDelta: Double? = {
            guard let value = current?.restingHeartRate,
                  let baseline = baseline(for: series(\.restingHeartRate), window: .primary, asOf: date) else {
                return nil
            }
            return value - baseline.mean
        }()

        return BaselineDeltas(
            sleepDelta: relative(\.sleepHours),
            hrvDelta: relative(\.hrvSDNN),
            restingHRDeltaBPM: restingHRDelta
        )
    }
}
