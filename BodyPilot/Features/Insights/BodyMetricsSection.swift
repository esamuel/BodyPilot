import Charts
import SwiftUI

/// Hero for the Recovery insight: the readiness verdict as a large headline
/// over a warm-to-calm gradient wash, with the deterministic summary beneath
/// and the Body Score as a prominent ring.
struct RecoveryVerdictHero: View {
    let statusLabel: String
    let summary: String
    let score: Int?
    let status: InsightStatus

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            HStack(alignment: .top, spacing: BPSpacing.medium) {
                Text(statusLabel)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(BodyPilotColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let score {
                    ScoreRing(score: score, status: status)
                }
            }
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(
            LinearGradient(
                colors: [
                    BodyPilotColors.warmGlow,
                    Color(red: 0.93, green: 0.97, blue: 0.90),
                    Color(red: 0.86, green: 0.95, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: BPCornerRadius.card)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The Body Score number inside a progress ring, tinted by status.
private struct ScoreRing: View {
    let score: Int
    let status: InsightStatus

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(score)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(BodyPilotColors.primaryText)
                Text("Score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 76, height: 76)
        .accessibilityLabel(Text("Body Score \(score) out of 100"))
    }

    private var ringColor: Color {
        switch status {
        case .excellent, .good: BodyPilotColors.successGreen
        case .steady: BodyPilotColors.warningOrange
        case .low: BodyPilotColors.accentOrange
        case .unknown: BodyPilotColors.secondaryText
        }
    }
}

/// "Body metrics" cards: latest value, personal-baseline status, and a
/// dot sparkline of the recent nights, latest point highlighted.
struct BodyMetricsSection: View {
    let metrics: [BodyMetricReading]

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Body metrics")
                .font(.headline)
            Text("Measured against your own recent normal")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(metrics, id: \.self) { metric in
                BodyMetricCard(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BodyMetricCard: View {
    let metric: BodyMetricReading

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Label(metric.label, systemImage: metric.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BodyPilotColors.primaryText)

            HStack(alignment: .center, spacing: BPSpacing.medium) {
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Text(metric.valueText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(BodyPilotColors.primaryText)
                    Label {
                        Text(metric.statusText)
                            .font(.footnote.weight(.semibold))
                    } icon: {
                        Image(systemName: statusSymbol)
                            .font(.footnote)
                    }
                    .foregroundStyle(statusColor)
                }
                Spacer()
                if metric.recentValues.count >= 2 {
                    MetricSparkline(values: metric.recentValues)
                        .frame(width: 120, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch metric.status {
        case .excellent, .good: BodyPilotColors.successGreen
        case .steady, .low: BodyPilotColors.secondaryText
        case .unknown: BodyPilotColors.secondaryText
        }
    }

    private var statusSymbol: String {
        switch metric.status {
        case .excellent, .good: "checkmark.circle.fill"
        case .steady, .low: "circle.dashed"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Small dot-and-line trend of recent values; the newest point is emphasized.
private struct MetricSparkline: View {
    let values: [Double]

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(
                x: .value("Day", index),
                y: .value("Value", value)
            )
            .foregroundStyle(Color.gray.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            PointMark(
                x: .value("Day", index),
                y: .value("Value", value)
            )
            .foregroundStyle(
                index == values.count - 1 ? BodyPilotColors.successGreen : Color.gray.opacity(0.55)
            )
            .symbolSize(index == values.count - 1 ? 70 : 36)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

#Preview("Recovery hero") {
    RecoveryVerdictHero(
        statusLabel: "Ready for a normal day",
        summary: "Your recovery signals are close to or better than your personal norm. Today supports your planned training.",
        score: 72,
        status: .good
    )
    .padding()
}

#Preview("Body metrics") {
    ScrollView {
        BodyMetricsSection(metrics: [
            BodyMetricReading(
                label: "Resting Heart Rate",
                systemImage: "heart.fill",
                valueText: "45 bpm",
                status: .good,
                statusText: "Normal for you",
                recentValues: [48, 47, 49, 46, 47, 45, 45]
            ),
            BodyMetricReading(
                label: "Heart Rate Variability",
                systemImage: "waveform.path.ecg",
                valueText: "38 ms",
                status: .steady,
                statusText: "Below your usual",
                recentValues: [46, 44, 48, 43, 41, 40, 38]
            ),
            BodyMetricReading(
                label: "Sleep",
                systemImage: "moon.zzz.fill",
                valueText: "—",
                status: .unknown,
                statusText: "No recent readings",
                recentValues: []
            ),
        ])
        .padding()
    }
}
