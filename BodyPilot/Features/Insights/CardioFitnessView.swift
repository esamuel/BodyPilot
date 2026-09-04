import Charts
import SwiftUI

struct CardioFitnessView: View {
    let statusLabel: String
    let summary: String
    let data: CardioFitnessData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.large) {
                CardioHero(statusLabel: statusLabel, summary: summary)
                CardioOverview(data: data)
                AboutCardioFitness(vo2Max: data.vo2Max)
            }
            .padding(BPSpacing.medium)
        }
        .navigationTitle("Cardio Fitness")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardioHero: View {
    let statusLabel: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.65))
                    .frame(width: 112, height: 112)
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.heartCoral)
                Image(systemName: "waveform.path.ecg")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            Text(statusLabel)
                .font(.title.bold())
            Text(summary)
                .font(.body)
                .foregroundStyle(BodyPilotColors.primaryText)
        }
        .padding(BPSpacing.large)
        .background(
            LinearGradient(
                colors: [.heartCoral.opacity(0.30), .white.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: BPCornerRadius.card)
        )
    }
}

private enum CardioMetric: String, CaseIterable, Identifiable {
    case restingHeartRate
    case steps
    case activityDuration
    case activityDistance
    case activityEnergy

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .restingHeartRate: "Resting Heart Rate"
        case .steps: "Steps — Daily Av."
        case .activityDuration: "Activity Duration"
        case .activityDistance: "Activity Distance"
        case .activityEnergy: "Activity Energy"
        }
    }

    var accessibilityTitle: LocalizedStringResource {
        switch self {
        case .restingHeartRate: "Resting Heart Rate"
        case .steps: "Steps — Daily Average"
        case .activityDuration: "Activity Duration"
        case .activityDistance: "Activity Distance"
        case .activityEnergy: "Activity Energy"
        }
    }

    var systemImage: String {
        switch self {
        case .restingHeartRate: "heart.fill"
        case .steps: "figure.walk"
        case .activityDuration: "clock.fill"
        case .activityDistance: "location.fill"
        case .activityEnergy: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .restingHeartRate: BodyPilotColors.deepPurple
        case .steps: .movementAmber
        case .activityDuration: BodyPilotColors.warningOrange
        case .activityDistance: BodyPilotColors.coreBlue
        case .activityEnergy: .heartCoral
        }
    }

    var usesLineChart: Bool {
        self == .restingHeartRate
    }

    func values(in data: CardioFitnessData) -> [DatedValue] {
        switch self {
        case .restingHeartRate: data.restingHeartRate
        case .steps: data.steps
        case .activityDuration: data.activityDuration
        case .activityDistance: data.activityDistance
        case .activityEnergy: data.activityEnergy
        }
    }

    func valueText(_ value: Double) -> String {
        switch self {
        case .restingHeartRate:
            return String(localized: "\(Int(value.rounded())) bpm")
        case .steps:
            return Int(value.rounded()).formatted()
        case .activityDuration:
            return String(localized: "\(Int(value.rounded())) min")
        case .activityDistance:
            return String(localized: "\((value / 1_000).formatted(.number.precision(.fractionLength(1)))) km")
        case .activityEnergy:
            return String(localized: "\(Int(value.rounded())) kcal")
        }
    }
}

private enum CardioDateRange: Hashable {
    case twelveMonths
    case year(Int)

    var title: String {
        switch self {
        case .twelveMonths:
            String(localized: "12 Months")
        case .year(let year):
            year.formatted(.number.grouping(.never))
        }
    }
}

private struct MonthlyCardioValue: Identifiable, Equatable {
    let month: Date
    let average: Double
    let sampleCount: Int

    var id: Date { month }
}

private struct CardioOverview: View {
    let data: CardioFitnessData

    @Environment(\.calendar) private var calendar
    @State private var selectedMetric = CardioMetric.restingHeartRate
    @State private var selectedRange = CardioDateRange.twelveMonths

    private var ranges: [CardioDateRange] {
        let years = Set(allDates.map { calendar.component(.year, from: $0) })
        return [.twelveMonths] + years.sorted(by: >).map(CardioDateRange.year)
    }

    private var allDates: [Date] {
        CardioMetric.allCases.flatMap { $0.values(in: data).map(\.date) }
    }

    private var visibleValues: [DatedValue] {
        let values = selectedMetric.values(in: data)
        switch selectedRange {
        case .twelveMonths:
            let cutoff = calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            return values.filter { $0.date >= cutoff }
        case .year(let year):
            return values.filter { calendar.component(.year, from: $0.date) == year }
        }
    }

    private var monthlyValues: [MonthlyCardioValue] {
        let grouped = Dictionary(grouping: visibleValues) { value -> DateComponents in
            calendar.dateComponents([.year, .month], from: value.date)
        }
        return grouped.compactMap { components, values in
            guard let month = calendar.date(from: components), !values.isEmpty else {
                return nil
            }
            let average = values.reduce(0) { $0 + $1.value } / Double(values.count)
            return MonthlyCardioValue(
                month: month,
                average: average,
                sampleCount: values.count
            )
        }
        .sorted { $0.month < $1.month }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Overview")
                .font(.title2.bold())

            CardioRangePicker(
                ranges: ranges,
                selection: $selectedRange,
                accent: selectedMetric.color
            )
            CardioTrendChart(metric: selectedMetric, values: monthlyValues)
            CardioMetricPicker(selection: $selectedMetric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardioRangePicker: View {
    let ranges: [CardioDateRange]
    @Binding var selection: CardioDateRange
    let accent: Color

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BPSpacing.small) {
                ForEach(ranges, id: \.self) { range in
                    Button(range.title) {
                        selection = range
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(selection == range ? .white : BodyPilotColors.primaryText)
                    .padding(.horizontal, BPSpacing.medium)
                    .padding(.vertical, BPSpacing.small)
                    .background(
                        selection == range ? accent : Color.secondary.opacity(0.12),
                        in: Capsule()
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct CardioTrendChart: View {
    let metric: CardioMetric
    let values: [MonthlyCardioValue]

    @State private var selectedDate: Date?

    private var periodAverage: Double? {
        let sampleCount = values.reduce(0) { $0 + $1.sampleCount }
        guard sampleCount > 0 else { return nil }
        let weightedTotal = values.reduce(0) {
            $0 + $1.average * Double($1.sampleCount)
        }
        return weightedTotal / Double(sampleCount)
    }

    private var selectedValue: MonthlyCardioValue? {
        guard let selectedDate else { return nil }
        return values.min {
            abs($0.month.timeIntervalSince(selectedDate))
                < abs($1.month.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Label(metric.title, systemImage: metric.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let periodAverage {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Period Av.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(metric.valueText(periodAverage))
                            .font(.title3.bold())
                            .foregroundStyle(metric.color)
                    }
                }
            }

            if values.isEmpty {
                ContentUnavailableView(
                    "No readings in this period",
                    systemImage: metric.systemImage,
                    description: Text("Keep Apple Health connected as your history builds.")
                )
                .frame(minHeight: 220)
            } else {
                Chart {
                    ForEach(values) { item in
                        if metric.usesLineChart {
                            LineMark(
                                x: .value("Month", item.month, unit: .month),
                                y: .value("Monthly average", item.average)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(metric.color)
                            .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))

                            PointMark(
                                x: .value("Month", item.month, unit: .month),
                                y: .value("Monthly average", item.average)
                            )
                            .foregroundStyle(metric.color)
                            .symbolSize(28)
                        } else {
                            BarMark(
                                x: .value("Month", item.month, unit: .month),
                                y: .value("Monthly average", item.average)
                            )
                            .foregroundStyle(metric.color)
                            .cornerRadius(7)
                        }
                    }

                    if let periodAverage {
                        RuleMark(y: .value("Period average", periodAverage))
                            .foregroundStyle(metric.color.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    }

                    if let selectedValue {
                        RuleMark(x: .value("Selected month", selectedValue.month, unit: .month))
                            .foregroundStyle(.secondary.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(position: .top, spacing: BPSpacing.xSmall) {
                                VStack(spacing: 2) {
                                    Text("Av. \(metric.valueText(selectedValue.average))")
                                        .font(.subheadline.weight(.semibold))
                                    Text(
                                        selectedValue.month,
                                        format: .dateTime.month(.wide).year()
                                    )
                                    .font(.subheadline)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, BPSpacing.small)
                                .padding(.vertical, BPSpacing.xSmall)
                                .background(metric.color, in: .rect(cornerRadius: BPCornerRadius.control))
                            }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing)
                }
                .frame(height: 260)
                .accessibilityLabel(Text("\(metric.title) monthly-average trend"))
                .accessibilityValue(
                    periodAverage.map { Text("Period average \(metric.valueText($0))") }
                        ?? Text("No readings")
                )
                .onChange(of: values) {
                    selectedDate = nil
                }
            }
        }
        .padding(BPSpacing.medium)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct CardioMetricPicker: View {
    @Binding var selection: CardioMetric

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BPSpacing.small) {
                ForEach(CardioMetric.allCases) { metric in
                    Button {
                        selection = metric
                    } label: {
                        Label(metric.title, systemImage: metric.systemImage)
                            .lineLimit(1)
                    }
                    .accessibilityLabel(metric.accessibilityTitle)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selection == metric ? .white : BodyPilotColors.primaryText)
                    .padding(.horizontal, BPSpacing.medium)
                    .padding(.vertical, BPSpacing.small)
                    .background(
                        selection == metric ? metric.color : Color.secondary.opacity(0.12),
                        in: Capsule()
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct AboutCardioFitness: View {
    let vo2Max: [DatedValue]

    @State private var isExpanded = true

    private var latestVO2Max: Double? {
        vo2Max.last?.value
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: BPSpacing.medium) {
                HStack {
                    Label("VO₂ Max", systemImage: "lungs.fill")
                        .font(.headline)
                    Spacer()
                    Text(latestVO2Max.map {
                        String(localized: "\($0.formatted(.number.precision(.fractionLength(1)))) ml/kg/min")
                    } ?? "—")
                    .font(.title3.bold())
                    .foregroundStyle(.heartCoral)
                }

                Text("VO₂ max estimates how much oxygen your body can use during exercise. Apple Watch can add estimates after qualifying outdoor walks, runs, or hikes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if latestVO2Max == nil {
                    Label(
                        "No recent estimate yet. A few regular outdoor sessions with Apple Watch can help build this trend.",
                        systemImage: "applewatch"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, BPSpacing.medium)
        } label: {
            Text("About Cardio Fitness")
                .font(.title2.bold())
                .foregroundStyle(BodyPilotColors.primaryText)
        }
        .padding(BPSpacing.large)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

#Preview {
    NavigationStack {
        CardioFitnessView(
            statusLabel: "Your cardio trends",
            summary: "See how your resting heart rate and daily activity move together over time.",
            data: CardioFitnessData(
                restingHeartRate: [],
                steps: [],
                activityDuration: [],
                activityDistance: [],
                activityEnergy: [],
                vo2Max: []
            )
        )
    }
}
