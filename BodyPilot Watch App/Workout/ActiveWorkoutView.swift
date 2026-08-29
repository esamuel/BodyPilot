import SwiftUI

/// Glanceable live workout per PRD priority: current step, heart rate,
/// elapsed time, then next action.
struct ActiveWorkoutView: View {
    @Environment(WorkoutSessionManager.self) private var session
    @State private var isEndConfirmationPresented = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: BPSpacing.small) {
                    currentStepSection
                    metricsSection
                    if let next = session.nextStep {
                        Text("Next: \(next.name)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    controls
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $isEndConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                session.end()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This stops tracking and opens the summary so you can save the workout.")
        }
    }

    @ViewBuilder
    private var currentStepSection: some View {
        if let step = session.currentStep {
            Text(step.name)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.8)
            Text(step.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let remaining = session.remainingMinutesInStep {
                Text("\(Int(remaining.rounded(.up))) min left in step")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let coachingCue = step.coachingCue {
                Label(coachingCue, systemImage: "checkmark.seal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("All steps done — finish when ready.")
                .font(.headline)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
            Label {
                Text(heartRateText)
                    .font(.title3.monospacedDigit())
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Heart rate \(heartRateText)")
            Text(elapsedText)
                .font(.title2.monospacedDigit())
                .accessibilityLabel("Elapsed time \(elapsedText)")
        }
    }

    private var controls: some View {
        HStack(spacing: BPSpacing.small) {
            if session.phase == .paused {
                Button("Resume") {
                    session.resume()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Pause") {
                    session.pause()
                }
                .buttonStyle(.bordered)
            }
            Button("End") {
                isEndConfirmationPresented = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.top, BPSpacing.small)
    }

    private var heartRateText: String {
        if let heartRate = session.heartRate {
            return "\(Int(heartRate.rounded())) BPM"
        }
        return "--"
    }

    private var elapsedText: String {
        Duration.seconds(session.elapsedSeconds)
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    ActiveWorkoutView()
        .environment(WorkoutSessionManager())
}
