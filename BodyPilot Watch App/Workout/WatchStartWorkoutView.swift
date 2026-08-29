import SwiftUI

/// Entry point for starting a workout from the wrist. The recommended plan is
/// generated on-device from the shared readiness engines.
struct WatchStartWorkoutView: View {
    @Environment(WorkoutSessionManager.self) private var session
    @State private var model = WatchWorkoutModel()

    var body: some View {
        List {
            Section("Recommended") {
                switch model.state {
                case .loading:
                    ProgressView()
                        .accessibilityLabel("Preparing your recommendation")
                case .ready(let plan):
                    planButton(plan)
                case .needsHealthAccess:
                    Button("Allow Health Access") {
                        Task {
                            await model.requestAccess()
                        }
                    }
                case .failed(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Quick Start") {
                ForEach(model.quickPlans, id: \.self) { plan in
                    planButton(plan)
                }
            }
        }
        .navigationTitle("Workout")
        .task {
            await model.load()
        }
    }

    private func planButton(_ plan: PlannedWorkout) -> some View {
        Button {
            Task {
                await session.start(plan: plan)
            }
        } label: {
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(plan.title)
                    .font(.headline)
                Text(plan.intensity.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchStartWorkoutView()
    }
    .environment(WorkoutSessionManager())
}
