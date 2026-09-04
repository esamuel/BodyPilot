import SwiftUI

struct RecapSection: View {
    let recaps: [RecapSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Recaps")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(recaps) { recap in
                RecapCard(recap: recap)
            }
        }
    }
}

struct RecapPreviewCard: View {
    let recap: RecapSummary

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
                LoadChangeBadge(change: recap.loadChangeFraction)
            }
            Text("\(recap.activeDays) active days · \(recap.workoutCount) workouts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(recap.distanceMeters / 1_000, format: .number.precision(.fractionLength(1))) km")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
        .accessibilityElement(children: .combine)
    }
}

private struct RecapCard: View {
    let recap: RecapSummary

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: BPSpacing.medium)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            HStack {
                if recap.period == .week {
                    Text("Weekly Recap")
                        .font(.headline)
                } else {
                    Text("Monthly Recap")
                        .font(.headline)
                }
                Spacer()
                LoadChangeBadge(change: recap.loadChangeFraction)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: BPSpacing.medium) {
                RecapMetric(title: "Active days", value: "\(recap.activeDays)")
                RecapMetric(title: "Workouts", value: "\(recap.workoutCount)")
                RecapMetric(
                    title: "Distance",
                    value: "\(recap.distanceMeters / 1_000, format: .number.precision(.fractionLength(1))) km"
                )
                RecapMetric(
                    title: "Energy",
                    value: "\(Int(recap.energyKilocalories.rounded())) kcal"
                )
                if recap.photoCount > 0 {
                    RecapMetric(title: "Photos", value: "\(recap.photoCount)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct RecapMetric: View {
    let title: LocalizedStringResource
    let value: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct LoadChangeBadge: View {
    let change: Double?

    var body: some View {
        if let change {
            let percent = Int((abs(change) * 100).rounded())
            Label(
                "\(percent)%",
                systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(change > 0.15 ? BodyPilotColors.warningOrange : Color.routeTeal)
            .accessibilityLabel(
                "Training load is \(percent) percent \(change >= 0 ? "higher" : "lower") than the previous period"
            )
        } else {
            Text("New baseline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
