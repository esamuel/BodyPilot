import SwiftData
import SwiftUI

/// Read-only heart rate zones derived deterministically from the user's age
/// (estimated max heart rate) and their resting heart rate from Apple Health.
struct HeartRateZonesView: View {
    @Query private var profiles: [UserProfile]
    @State private var restingHeartRate: Int?

    private let healthMetrics: any HealthMetricsProviding

    init(healthMetrics: any HealthMetricsProviding = HealthKitClient()) {
        self.healthMetrics = healthMetrics
    }

    private var zoneProfile: HeartRateZoneProfile {
        HeartRateZoneEngine.profile(
            maximumHeartRate: HeartRateZoneEngine.estimatedMaximumHeartRate(age: profiles.first?.age),
            restingHeartRate: restingHeartRate ?? HeartRateZoneEngine.fallbackRestingHeartRate
        )
    }

    var body: some View {
        List {
            Section {
                Text("Heart rate is a reliable measure of how hard an activity works your body. Training zones translate it into effort levels you can plan around.")
                    .font(.subheadline)
                    .foregroundStyle(BodyPilotColors.secondaryText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                LabeledContent("Estimated Max Heart Rate") {
                    Text("\(zoneProfile.maximumHeartRate) bpm")
                }
                LabeledContent("Resting Heart Rate") {
                    Text("\(zoneProfile.restingHeartRate) bpm")
                }
            } header: {
                Text("Your Zones")
            } footer: {
                footerText
            }

            Section {
                HeartRateZoneRow(
                    color: .gray,
                    title: Text("Zone 0 · Easy"),
                    range: Text("Below \(zoneProfile.easyUpperBoundBPM) bpm"),
                    description: Text("Gentle movement like an easy walk, stretching, or resting between exercises.")
                )
                ForEach(zoneProfile.zones, id: \.index) { zone in
                    HeartRateZoneRow(
                        color: Self.zoneColor(for: zone.index),
                        title: Self.zoneTitle(for: zone.index),
                        range: Text("\(zone.lowerBoundBPM)–\(zone.upperBoundBPM) bpm"),
                        description: Self.zoneDescription(for: zone.index)
                    )
                }
            }
        }
        .navigationTitle("Heart Rate Zones")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRestingHeartRate()
        }
    }

    private var footerText: Text {
        if profiles.first?.age == nil && restingHeartRate == nil {
            Text("Add your birth date in Personal Details and connect Apple Health for zones tailored to you. Typical values are shown until then.")
        } else if profiles.first?.age == nil {
            Text("Add your birth date in Personal Details to sharpen the max heart rate estimate.")
        } else if restingHeartRate == nil {
            Text("Connect Apple Health so BodyPilot can use your measured resting heart rate.")
        } else {
            Text("Max heart rate is estimated from your age. Resting heart rate comes from Apple Health.")
        }
    }

    /// Most recent resting heart rate from the last two weeks of daily snapshots.
    private func loadRestingHeartRate() async {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        guard let snapshots = try? await healthMetrics.dailySnapshots(from: start, to: .now) else {
            return
        }
        let latest = snapshots
            .sorted { $0.date > $1.date }
            .compactMap(\.restingHeartRate)
            .first
        if let latest {
            restingHeartRate = Int(latest.rounded())
        }
    }

    // MARK: - Zone presentation

    private static func zoneColor(for index: Int) -> Color {
        switch index {
        case 1: BodyPilotColors.remBlue
        case 2: .yellow
        case 3: BodyPilotColors.warningOrange
        case 4: .red
        default: BodyPilotColors.deepPurple
        }
    }

    private static func zoneTitle(for index: Int) -> Text {
        switch index {
        case 1: Text("Zone 1 · Warm Up")
        case 2: Text("Zone 2 · Endurance")
        case 3: Text("Zone 3 · Moderate")
        case 4: Text("Zone 4 · Intense")
        default: Text("Zone 5 · Performance")
        }
    }

    private static func zoneDescription(for index: Int) -> Text {
        switch index {
        case 1: Text("Warming up, cooling down, and recovering from earlier workouts.")
        case 2: Text("Comfortable effort that builds endurance and burns fat without long recovery.")
        case 3: Text("Steady effort that improves general cardiovascular fitness.")
        case 4: Text("Hard effort that builds speed and tolerance for intense work.")
        default: Text("Near-maximal effort. Keep visits short and purposeful.")
        }
    }
}

private struct HeartRateZoneRow: View {
    let color: Color
    let title: Text
    let range: Text
    let description: Text

    var body: some View {
        HStack(alignment: .top, spacing: BPSpacing.small) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                HStack {
                    title
                        .font(.headline)
                        .foregroundStyle(BodyPilotColors.primaryText)
                    Spacer()
                    range
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BodyPilotColors.secondaryText)
                }
                description
                    .font(.footnote)
                    .foregroundStyle(BodyPilotColors.secondaryText)
            }
        }
        .padding(.vertical, BPSpacing.xSmall)
    }
}

#Preview {
    NavigationStack {
        HeartRateZonesView(healthMetrics: MockHealthProvider())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}
