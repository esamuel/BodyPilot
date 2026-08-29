import SwiftUI

/// Post-workout summary with the perceived-effort prompt per PRD 7.8.
/// The answer is saved as workout metadata for future personalization.
struct WorkoutSummaryView: View {
    @Environment(WorkoutSessionManager.self) private var session

    private static let effortOptions: [(key: String, label: LocalizedStringResource)] = [
        ("tooEasy", "Too easy"),
        ("right", "Right"),
        ("hard", "Hard"),
        ("tooHard", "Too hard"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.small) {
                Text("Nice work!")
                    .font(.headline)
                summaryRows
                Divider()
                Text("How did that feel?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(Self.effortOptions, id: \.key) { option in
                    Button {
                        Task {
                            await session.finish(perceivedEffort: option.key)
                        }
                    } label: {
                        Text(option.label)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Skip") {
                    Task {
                        await session.finish(perceivedEffort: nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summaryRows: some View {
        VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
            summaryRow(
                label: "Duration",
                value: Duration.seconds(session.elapsedSeconds).formatted(.time(pattern: .minuteSecond))
            )
            if let average = session.averageHeartRate {
                summaryRow(label: "Avg heart rate", value: "\(Int(average.rounded())) BPM")
            }
            if let energy = session.activeEnergyKilocalories {
                summaryRow(label: "Active energy", value: "\(Int(energy.rounded())) kcal")
            }
        }
    }

    private func summaryRow(label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospacedDigit())
        }
    }
}

#Preview {
    WorkoutSummaryView()
        .environment(WorkoutSessionManager())
}
