import Charts
import SwiftUI

struct CorridorChart: View {
    let corridor: ActivityCorridor

    var body: some View {
        Chart(corridor.days) { day in
            AreaMark(
                x: .value("Date", day.date, unit: .day),
                yStart: .value("Lower bound", day.lowerBound),
                yEnd: .value("Upper bound", day.upperBound)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                corridor.isPaused
                    ? Color.secondary.opacity(0.18)
                    : BodyPilotColors.successGreen.opacity(0.18)
            )

            LineMark(
                x: .value("Date", day.date, unit: .day),
                y: .value("Activity load", day.load)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(corridor.isPaused ? Color.secondary : Color.routeTeal)

            PointMark(
                x: .value("Date", day.date, unit: .day),
                y: .value("Activity load", day.load)
            )
            .symbolSize(36)
            .foregroundStyle(corridor.isPaused ? Color.secondary : day.state.tint)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(minHeight: 190)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity corridor")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let today = corridor.today else {
            return String(localized: "No activity corridor data is available.")
        }
        return String(
            localized: "Today your load is \(Int(today.load.rounded())). Your healthy range is \(Int(today.lowerBound.rounded())) to \(Int(today.upperBound.rounded()))."
        )
    }
}
