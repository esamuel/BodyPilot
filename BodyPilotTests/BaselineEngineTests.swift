import Foundation
import Testing
@testable import BodyPilot

struct BaselineEngineTests {
    /// Fixed UTC calendar so results don't depend on the machine's time zone.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let engine = BaselineEngine(calendar: utcCalendar)
    /// 2026-01-31 00:00 UTC — "today" for these tests.
    private let today = Date(timeIntervalSince1970: 1_769_817_600)

    private func day(_ offset: Int) -> Date {
        today.addingTimeInterval(Double(offset) * 86_400)
    }

    private func values(_ pairs: [(offset: Int, value: Double)]) -> [DatedValue] {
        pairs.map { DatedValue(date: day($0.offset), value: $0.value) }
    }

    @Test("Baseline is the mean and standard deviation of in-window values")
    func baselineStatistics() throws {
        let series = values([(-1, 8), (-2, 6), (-3, 7), (-4, 7)])
        let baseline = try #require(engine.baseline(for: series, window: .short, asOf: today))
        #expect(baseline.mean == 7)
        #expect(abs(baseline.standardDeviation - 0.7071) < 0.001)
        #expect(baseline.sampleCount == 4)
    }

    @Test("Today's value is excluded from its own baseline")
    func excludesToday() throws {
        let series = values([(0, 100), (-1, 7), (-2, 7), (-3, 7), (-4, 7)])
        let baseline = try #require(engine.baseline(for: series, window: .short, asOf: today))
        #expect(baseline.mean == 7)
        #expect(baseline.sampleCount == 4)
    }

    @Test("Values older than the window are excluded")
    func excludesValuesOutsideWindow() throws {
        let series = values([(-1, 7), (-2, 7), (-3, 7), (-4, 7), (-8, 100), (-30, 100)])
        let baseline = try #require(engine.baseline(for: series, window: .short, asOf: today))
        #expect(baseline.mean == 7)
        #expect(baseline.sampleCount == 4)
    }

    @Test("Fewer samples than the minimum yields no baseline")
    func insufficientSamples() {
        let series = values([(-1, 7), (-2, 7), (-3, 7)])
        #expect(engine.baseline(for: series, window: .short, asOf: today) == nil)
        #expect(engine.baseline(for: [], window: .primary, asOf: today) == nil)
    }

    @Test("Relative delta is (current − mean) / mean")
    func relativeDelta() throws {
        let series = values([(-1, 8), (-2, 8), (-3, 8), (-4, 8)])
        let baseline = try #require(engine.baseline(for: series, window: .short, asOf: today))
        let delta = try #require(engine.relativeDelta(current: 7.2, baseline: baseline))
        #expect(abs(delta - (-0.1)) < 0.000_1)
    }

    @Test("Relative delta is nil for a non-positive baseline mean")
    func relativeDeltaGuardsZeroMean() {
        let baseline = MetricBaseline(mean: 0, standardDeviation: 0, sampleCount: 14, window: .primary)
        #expect(engine.relativeDelta(current: 5, baseline: baseline) == nil)
    }

    @Test("Deltas come back nil when today's data or history is missing")
    func deltasWithMissingData() {
        // History exists but today has no snapshot at all.
        let history = (1...20).map { offset in
            DailyHealthSnapshot(
                date: day(-offset), sleepHours: 7, hrvSDNN: 50, restingHeartRate: 60,
                steps: nil, activeEnergyKilocalories: nil, exerciseMinutes: nil
            )
        }
        let deltas = engine.deltas(for: history, asOf: today)
        #expect(deltas.sleepDelta == nil)
        #expect(deltas.hrvDelta == nil)
        #expect(deltas.restingHRDeltaBPM == nil)
    }

    @Test("Deltas compare today's snapshot to the primary-window baseline")
    func deltasEndToEnd() throws {
        var snapshots = (1...20).map { offset in
            DailyHealthSnapshot(
                date: day(-offset), sleepHours: 8, hrvSDNN: 50, restingHeartRate: 60,
                steps: nil, activeEnergyKilocalories: nil, exerciseMinutes: nil
            )
        }
        snapshots.append(
            DailyHealthSnapshot(
                date: today, sleepHours: 7.2, hrvSDNN: 45, restingHeartRate: 63,
                steps: nil, activeEnergyKilocalories: nil, exerciseMinutes: nil
            )
        )

        let deltas = engine.deltas(for: snapshots, asOf: today)
        let sleepDelta = try #require(deltas.sleepDelta)
        let hrvDelta = try #require(deltas.hrvDelta)
        let restingHRDelta = try #require(deltas.restingHRDeltaBPM)
        #expect(abs(sleepDelta - (-0.1)) < 0.000_1)
        #expect(abs(hrvDelta - (-0.1)) < 0.000_1)
        #expect(abs(restingHRDelta - 3) < 0.000_1)
    }

    @Test("Extreme values keep the calculation finite and deterministic")
    func extremeValues() throws {
        let series = values([(-1, 1_000_000), (-2, 0.000_1), (-3, 500_000), (-4, 250_000)])
        let baseline = try #require(engine.baseline(for: series, window: .short, asOf: today))
        #expect(baseline.mean.isFinite)
        #expect(baseline.standardDeviation.isFinite)
    }
}
