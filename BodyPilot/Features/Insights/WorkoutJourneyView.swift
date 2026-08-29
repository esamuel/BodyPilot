import SwiftUI

/// Workout Journey world: recent workouts as milestones on a route rather than
/// a plain chronological list. Data comes from the deterministic snapshot plus
/// the normalized workout history.
struct WorkoutJourneyView: View {
    let snapshot: InsightSnapshot
    let workouts: [WorkoutSummary]
    let onAction: (SuggestedAction) -> Void

    private var recent: [WorkoutSummary] {
        Array(workouts.sorted { $0.start > $1.start }.prefix(10))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BPSpacing.large) {
                hero
                summaryCard
                if !recent.isEmpty {
                    routeCard
                }
                if let action = snapshot.action {
                    Button {
                        onAction(action)
                    } label: {
                        Text(action.title)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(snapshot.kind.accent)
                }
            }
            .padding(BPSpacing.medium)
        }
        .navigationTitle(Text(snapshot.kind.displayName))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            InsightHeroArt(resource: .journeyHeroArt)
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: BPCornerRadius.card))

            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(snapshot.statusLabel)
                    .font(.headline)
                Text(snapshot.primaryValueText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 4)
            .padding(BPSpacing.medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Workout journey: \(snapshot.statusLabel), \(snapshot.primaryValueText)"))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text(snapshot.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(snapshot.facts, id: \.self) { fact in
                Text(fact.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Your route")
                .font(.headline)
            ForEach(Array(recent.enumerated()), id: \.offset) { index, workout in
                HStack(spacing: BPSpacing.medium) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index == 0 ? Color.pilotBlue : Color.routeTeal)
                            .frame(width: index == 0 ? 14 : 10, height: index == 0 ? 14 : 10)
                        if index < recent.count - 1 {
                            Rectangle()
                                .fill(Color.routeTeal.opacity(0.4))
                                .frame(width: 2, height: 28)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.activity?.displayName ?? "Workout")
                            .font(.subheadline.weight(.medium))
                        Text(workout.start, format: .dateTime.weekday(.wide).day().month())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(workout.durationMinutes.rounded())) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

#Preview {
    NavigationStack {
        WorkoutJourneyView(
            snapshot: .previewRecovery,
            workouts: [
                WorkoutSummary(start: .now.addingTimeInterval(-86_400), durationMinutes: 32, activity: .walking, totalEnergyKilocalories: 180),
                WorkoutSummary(start: .now.addingTimeInterval(-3 * 86_400), durationMinutes: 25, activity: .strength, totalEnergyKilocalories: 150),
                WorkoutSummary(start: .now.addingTimeInterval(-5 * 86_400), durationMinutes: 40, activity: .walking, totalEnergyKilocalories: 210),
            ]
        ) { _ in }
    }
}
