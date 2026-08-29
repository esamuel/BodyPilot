import SwiftUI

/// "Explore your body" section on Today: one card per insight world, each
/// opening its dedicated page. Cards show status, headline value, and trend.
struct InsightsHubSection: View {
    let insights: [InsightSnapshot]
    let workouts: [WorkoutSummary]
    /// Handles a page CTA by generating and presenting a validated workout.
    let onAction: (SuggestedAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: BPSpacing.medium),
        GridItem(.flexible(), spacing: BPSpacing.medium),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Explore your body")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: BPSpacing.medium) {
                ForEach(insights, id: \.kind) { insight in
                    NavigationLink {
                        destination(for: insight)
                    } label: {
                        InsightCard(insight: insight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func destination(for insight: InsightSnapshot) -> some View {
        if insight.kind == .workoutHistory {
            WorkoutJourneyView(snapshot: insight, workouts: workouts, onAction: onAction)
        } else {
            InsightDetailView(snapshot: insight, onAction: onAction)
        }
    }
}

/// One hub card: themed icon, status, headline number, and a tiny trend arrow.
private struct InsightCard: View {
    let insight: InsightSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            HStack {
                Image(systemName: insight.kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(insight.kind.accent)
                Spacer()
                Image(systemName: insight.trend.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(insight.kind.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(insight.primaryValueText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(insight.kind.accent)
                .lineLimit(1)
            Text(insight.statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(BPSpacing.medium)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
        .contentShape(.rect(cornerRadius: BPCornerRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(insight.kind.displayName)): \(insight.statusLabel), \(insight.primaryValueText). \(Text(insight.trend.accessibilityDescription))"))
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            InsightsHubSection(
                insights: [.previewSleep, .previewRecovery],
                workouts: []
            ) { _ in }
            .padding()
        }
    }
}
