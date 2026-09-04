import Foundation
import Observation

enum SleepQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case needsAttention = "Needs attention"
}

struct SleepRange: Sendable {
    let lower: TimeInterval
    let upper: TimeInterval
}

@MainActor
@Observable
final class SleepModel {
    private(set) var nights: [SleepNight] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    var selectedDate = Calendar.current.startOfDay(for: .now)

    private let provider: any SleepDataProviding
    private let calendar: Calendar

    init(
        provider: any SleepDataProviding = HealthKitClient(),
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.calendar = calendar
    }

    var selectedNight: SleepNight? {
        nights.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var availableDates: [Date] { nights.map(\.date).sorted() }

    func refresh(now: Date = .now) async {
        isLoading = true
        errorMessage = nil
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -44, to: end) ?? end
        do {
            nights = try await provider.sleepNights(from: start, to: end)
            if selectedNight == nil, let latest = nights.last?.date {
                selectedDate = latest
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func moveSelection(by offset: Int) {
        guard let index = availableDates.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: selectedDate)
        }) else { return }
        let newIndex = min(max(0, index + offset), availableDates.count - 1)
        selectedDate = availableDates[newIndex]
    }

    func canMove(by offset: Int) -> Bool {
        guard let index = availableDates.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: selectedDate)
        }) else { return false }
        return availableDates.indices.contains(index + offset)
    }

    func quality(goalHours: Double) -> SleepQuality {
        guard let night = selectedNight else { return .needsAttention }
        let ratio = night.totalSleep / max(goalHours * 3600, 1)
        let restorativeRatio = night.restorativeSleep / max(night.totalSleep, 1)
        if ratio >= 1, restorativeRatio >= 0.25 { return .excellent }
        if ratio >= 0.9, restorativeRatio >= 0.20 { return .good }
        if ratio >= 0.8 { return .fair }
        return .needsAttention
    }

    func narrative(goalHours: Double) -> String {
        guard let night = selectedNight else {
            return String(localized: "Wear Apple Watch to bed or record sleep in Apple Health to see your guidance here.")
        }
        let ratio = night.totalSleep / max(goalHours * 3600, 1)
        let restorativeRatio = night.restorativeSleep / max(night.totalSleep, 1)
        let durationText: String
        if ratio >= 1.05 {
            durationText = String(localized: "Your sleep duration was above your goal")
        } else if ratio >= 0.9 {
            durationText = String(localized: "Your sleep duration was close to your goal")
        } else {
            durationText = String(localized: "Your sleep duration was under your goal")
        }
        let recoveryText = restorativeRatio >= 0.25
            ? String(localized: "and included a healthy share of restorative sleep.")
            : String(localized: "and included less restorative sleep than your usual target.")
        let awakeText = night.awakeDuration <= 35 * 60
            ? String(localized: "Your recorded awake time was within a typical range.")
            : String(localized: "You also spent more time awake during the night than usual.")
        return "\(durationText) \(recoveryText) \(awakeText)"
    }

    var recentNights: [SleepNight] { Array(nights.suffix(14)) }
    var baselineNights: [SleepNight] { Array(nights.suffix(30)) }

    var averageSleep: TimeInterval { average(baselineNights.map(\.totalSleep)) }
    var averageRestorative: TimeInterval { average(baselineNights.map(\.restorativeSleep)) }

    var durationVariability: TimeInterval {
        let values = baselineNights.map(\.totalSleep)
        guard !values.isEmpty else { return 0 }
        let mean = average(values)
        return sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count))
    }

    func averageDuration(for stage: SleepStage) -> TimeInterval {
        average(baselineNights.map { $0.duration(for: stage) })
    }

    func optimalDurationRange(goalHours: Double) -> SleepRange {
        SleepRange(lower: goalHours * 3600 * 0.9, upper: goalHours * 3600 * 1.1)
    }

    func optimalRestorativeRange(goalHours: Double) -> SleepRange {
        SleepRange(lower: goalHours * 3600 * 0.25, upper: goalHours * 3600 * 0.45)
    }

    func optimalStageRange(_ stage: SleepStage, goalHours: Double) -> SleepRange {
        let percentages: (Double, Double) = switch stage {
        case .rem: (0.15, 0.25)
        case .core, .asleepUnspecified: (0.55, 0.75)
        case .deep: (0.10, 0.20)
        case .awake: (0, 0.10)
        }
        return SleepRange(
            lower: goalHours * 3600 * percentages.0,
            upper: goalHours * 3600 * percentages.1
        )
    }

    func status(for value: TimeInterval, range: SleepRange) -> (String, SleepStatusTone) {
        if value < range.lower * 0.85 { return (String(localized: "Very Low"), .critical) }
        if value < range.lower { return (String(localized: "Low"), .warning) }
        if value > range.upper * 1.15 { return (String(localized: "High"), .warning) }
        if value > range.upper { return (String(localized: "Above Normal"), .positive) }
        return (String(localized: "Normal"), .positive)
    }

    private func average(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

enum SleepStatusTone: Sendable {
    case positive
    case warning
    case critical
}
