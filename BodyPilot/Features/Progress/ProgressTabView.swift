import SwiftUI
import Charts

/// Progress per PRD 7.9: 7/30/90-day activity and recovery trends.
struct ProgressTabView: View {
    @State private var model: ProgressModel
    @State private var period: ProgressPeriod = .week

    init(model: ProgressModel = ProgressModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BPSpacing.large) {
                    Picker("Period", selection: $period) {
                        Text("7 days").tag(ProgressPeriod.week)
                        Text("30 days").tag(ProgressPeriod.month)
                        Text("90 days").tag(ProgressPeriod.quarter)
                    }
                    .pickerStyle(.segmented)
                    content
                }
                .padding(BPSpacing.medium)
            }
            .navigationTitle("Progress")
            .task(id: period) {
                await model.refresh(period: period)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .padding(BPSpacing.xLarge)
                .accessibilityLabel("Loading your progress")
        case .empty:
            ContentUnavailableView(
                "No Activity Yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Your trends will appear here after your first workouts.")
            )
            .padding(.top, BPSpacing.xLarge)
        case .failed(let message):
            VStack(spacing: BPSpacing.small) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    Task {
                        await model.refresh(period: period)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, BPSpacing.xLarge)
        case .ready(let summary):
            activityCard(summary)
            statsCard(summary)
            trendsCard(summary)
        }
    }

    // MARK: - Activity chart

    private func activityCard(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Active Minutes")
                .font(.headline)
            Chart(summary.dailyActiveMinutes, id: \.self) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Minutes", day.value)
                )
                .foregroundStyle(Color.routeTeal)
            }
            .frame(height: 160)
            .accessibilityLabel("Daily active minutes over the last \(summary.periodDays) days")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Stats

    private func statsCard(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Activity")
                .font(.headline)
            statRow("Workouts", value: "\(summary.workoutCount)")
            statRow("Active days", value: "\(summary.activeDays) of \(summary.periodDays)")
            statRow("Workout time", value: "\(Int(summary.totalWorkoutMinutes.rounded())) min")
            statRow("Cardio time", value: "\(Int(summary.cardioMinutes.rounded())) min")
            statRow("Strength sessions", value: "\(summary.strengthSessions)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    private func statRow(_ title: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
        }
    }

    // MARK: - Recovery trends

    private func trendsCard(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Recovery Signals")
                .font(.headline)
            if summary.sleepTrend == nil && summary.hrvTrend == nil && summary.restingHRTrend == nil {
                Text("Recovery trends appear once sleep and heart data build up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let sleep = summary.sleepTrend {
                trendRow(
                    "Sleep",
                    value: String(localized: "\(sleep.currentAverage.formatted(.number.precision(.fractionLength(1)))) h avg"),
                    trend: sleep,
                    higherIsBetter: true
                )
            }
            if let hrv = summary.hrvTrend {
                trendRow(
                    "HRV",
                    value: String(localized: "\(Int(hrv.currentAverage.rounded())) ms avg"),
                    trend: hrv,
                    higherIsBetter: true
                )
            }
            if let restingHR = summary.restingHRTrend {
                trendRow(
                    "Resting HR",
                    value: String(localized: "\(Int(restingHR.currentAverage.rounded())) BPM avg"),
                    trend: restingHR,
                    higherIsBetter: false
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    private func trendRow(
        _ title: LocalizedStringResource,
        value: String,
        trend: MetricTrend,
        higherIsBetter: Bool
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
            changeBadge(trend: trend, higherIsBetter: higherIsBetter)
        }
    }

    @ViewBuilder
    private func changeBadge(trend: MetricTrend, higherIsBetter: Bool) -> some View {
        if let change = trend.changeFraction {
            let percent = Int((abs(change) * 100).rounded())
            if percent == 0 {
                Text("steady")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let isImprovement = (change > 0) == higherIsBetter
                Label("\(percent)%", systemImage: change > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isImprovement ? .green : .orange)
                    .accessibilityLabel("\(percent) percent \(change > 0 ? "higher" : "lower") than the previous period")
            }
        }
    }
}

#Preview {
    ProgressTabView(model: ProgressModel(healthMetrics: MockHealthProvider()))
}
