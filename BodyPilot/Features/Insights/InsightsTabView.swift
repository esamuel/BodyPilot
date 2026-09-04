import SwiftData
import SwiftUI

struct InsightsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]
    @Query private var journalEntries: [WorkoutJournalEntry]

    @State private var healthAccess: HealthAccessModel
    @State private var model: TodayModel
    @State private var presentedWorkout: GeneratedWorkout?

    init(
        healthAccess: HealthAccessModel = HealthAccessModel(),
        model: TodayModel = TodayModel()
    ) {
        _healthAccess = State(initialValue: healthAccess)
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BPSpacing.large) {
                    if healthAccess.state == .connected {
                        insightsContent
                    } else {
                        InsightsHealthAccessCard(
                            state: healthAccess.state,
                            onConnect: connectHealth
                        )
                    }
                }
                .padding(BPSpacing.medium)
            }
            .navigationTitle("Insights")
            .task {
                await healthAccess.refresh()
                if healthAccess.state == .connected {
                    await refresh()
                }
            }
            .sheet(item: $presentedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    @ViewBuilder
    private var insightsContent: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .padding(BPSpacing.xLarge)
                .accessibilityLabel("Loading Body Insights")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t load insights", systemImage: "arrow.clockwise")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task {
                        await refresh()
                    }
                }
            }
        case .ready:
            if model.insights.isEmpty {
                ContentUnavailableView(
                    "Insights are taking shape",
                    systemImage: "sparkles",
                    description: Text("BodyPilot will explain your patterns as your health history builds.")
                )
            } else {
                InsightsHubSection(
                    insights: model.insights,
                    workouts: model.recentWorkouts,
                    onAction: startWorkout(for:)
                )
                if !model.recaps.isEmpty {
                    RecapSection(recaps: model.recaps)
                }
            }
        }
    }

    private var todaysCheckIn: CheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private func refresh() async {
        await model.refresh(
            checkIn: todaysCheckIn,
            profile: profiles.first,
            journalEntries: journalEntries
        )
    }

    private func connectHealth() {
        Task {
            await healthAccess.connect()
            if healthAccess.state == .connected {
                await refresh()
            }
        }
    }

    private func startWorkout(for action: SuggestedAction) {
        guard let plan = model.makeWorkout(for: action) else { return }
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        presentedWorkout = workout
    }
}

private struct InsightsHealthAccessCard: View {
    let state: HealthAccessModel.ConnectionState
    let onConnect: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connect Apple Health", systemImage: "heart.text.square")
        } description: {
            switch state {
            case .failed(let message):
                Text(message)
            case .unavailable:
                Text("Health data is not available on this device.")
            default:
                Text("Body Insights use your private, on-device health trends.")
            }
        } actions: {
            if state == .needsRequest {
                Button("Connect Apple Health", action: onConnect)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Insights English") {
    InsightsTabView(
        healthAccess: HealthAccessModel(healthProvider: MockHealthProvider()),
        model: TodayModel(healthMetrics: MockHealthProvider())
    )
    .modelContainer(
        for: [UserProfile.self, CheckIn.self, GeneratedWorkout.self, WorkoutJournalEntry.self],
        inMemory: true
    )
}

#Preview("Insights Hebrew RTL") {
    InsightsTabView(
        healthAccess: HealthAccessModel(healthProvider: MockHealthProvider()),
        model: TodayModel(healthMetrics: MockHealthProvider())
    )
    .modelContainer(
        for: [UserProfile.self, CheckIn.self, GeneratedWorkout.self, WorkoutJournalEntry.self],
        inMemory: true
    )
    .environment(\.locale, Locale(identifier: "he"))
    .environment(\.layoutDirection, .rightToLeft)
}
