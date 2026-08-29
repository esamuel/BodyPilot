import SwiftUI

/// Glanceable readiness summary synced from the iPhone readiness pipeline.
struct WatchTodayView: View {
    @State private var profileSync = WatchProfileSyncService.shared

    var body: some View {
        VStack(spacing: BPSpacing.medium) {
            Text("Body Score")
                .font(.headline)
            if let summary = profileSync.readinessSummary {
                WatchReadinessSummaryView(summary: summary)
            } else {
                WatchReadinessEmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, BPSpacing.small)
        .navigationTitle("Today")
        .task {
            profileSync.activate()
        }
    }
}

private struct WatchReadinessSummaryView: View {
    let summary: SyncedReadinessSummary

    var body: some View {
        VStack(spacing: BPSpacing.small) {
            Text("\(summary.bodyScore)")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(summary.readiness.tint)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .accessibilityLabel("Body Score \(summary.bodyScore)")
            Text(summary.readiness.displayName)
                .font(.headline)
                .foregroundStyle(summary.readiness.tint)
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Label(
                    "\(summary.recommendedMinMinutes)-\(summary.recommendedMaxMinutes) min",
                    systemImage: "clock"
                )
                Label {
                    Text(summary.intensity.displayName)
                } icon: {
                    Image(systemName: "gauge.with.needle")
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            if summary.isStale {
                Text("Open BodyPilot on iPhone for a fresh score.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct WatchReadinessEmptyView: View {
    var body: some View {
        VStack(spacing: BPSpacing.small) {
            Text(verbatim: "—")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .accessibilityLabel("Body Score not yet available")
            Text("Open BodyPilot on iPhone to calculate your Body Score.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
    }
}
