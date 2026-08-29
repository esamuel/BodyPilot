import SwiftUI
import SwiftData

/// Home screen per PRD hierarchy: Body Score, readiness message, recommended
/// workout, start action, and supporting signals.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]

    @State private var healthAccess: HealthAccessModel
    @State private var today: TodayModel
    @State private var isCheckInPresented = false
    @State private var presentedWorkout: GeneratedWorkout?

    init(
        healthAccess: HealthAccessModel = HealthAccessModel(),
        today: TodayModel = TodayModel()
    ) {
        _healthAccess = State(initialValue: healthAccess)
        _today = State(initialValue: today)
    }

    private var todaysCheckIn: CheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BPSpacing.large) {
                    bodyScoreCard
                    checkInCard
                    recommendationCard
                    if !today.insights.isEmpty {
                        InsightsHubSection(
                            insights: today.insights,
                            workouts: today.recentWorkouts,
                            onAction: startWorkout(for:)
                        )
                    }
                }
                .padding(BPSpacing.medium)
            }
            .navigationTitle("Today")
            .task {
                await healthAccess.refresh()
                await refreshScore()
            }
            .sheet(isPresented: $isCheckInPresented) {
                CheckInSheet { checkIn in
                    modelContext.insert(checkIn)
                    Task {
                        await refreshScore()
                    }
                }
            }
            .sheet(item: $presentedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    private func refreshScore() async {
        guard healthAccess.state == .connected else { return }
        await today.refresh(checkIn: todaysCheckIn, profile: profiles.first)
    }

    // MARK: - Body Score

    private var bodyScoreCard: some View {
        VStack(spacing: BPSpacing.small) {
            Text("Body Score")
                .font(.headline)
            scoreContent
        }
        .frame(maxWidth: .infinity)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    @ViewBuilder
    private var scoreContent: some View {
        if healthAccess.state == .connected {
            switch today.state {
            case .loading:
                ProgressView()
                    .padding(BPSpacing.medium)
                    .accessibilityLabel("Calculating your Body Score")
            case .ready(let score, _):
                Text("\(score.score)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(score.readiness.tint)
                    .accessibilityLabel("Body Score \(score.score)")
                Text(score.readiness.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(score.readiness.tint)
                if score.confidence < 0.5 {
                    Text("Limited data so far — this score will get more accurate as history builds.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                factsList(Array(score.explanationFacts.prefix(3)))
            case .failed(let message):
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task {
                        await refreshScore()
                    }
                }
                .buttonStyle(.bordered)
            }
        } else {
            Text(verbatim: "—")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .accessibilityLabel("Body Score not yet available")
            healthConnectionContent
        }
    }

    private func factsList(_ facts: [ExplanationFact]) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
            ForEach(facts, id: \.self) { fact in
                Text(fact.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, BPSpacing.xSmall)
    }

    @ViewBuilder
    private var healthConnectionContent: some View {
        switch healthAccess.state {
        case .checking:
            ProgressView()
                .accessibilityLabel("Checking Apple Health connection")
        case .unavailable:
            Text("Health data isn't available on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .needsRequest:
            Text("Connect Apple Health to see how your body is doing today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Connect Apple Health") {
                Task {
                    await healthAccess.connect()
                    await refreshScore()
                }
            }
            .buttonStyle(.borderedProminent)
        case .connected:
            EmptyView()
        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await healthAccess.refresh()
                    await refreshScore()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Check-in

    private var checkInCard: some View {
        HStack(spacing: BPSpacing.medium) {
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text("Daily Check-in")
                    .font(.headline)
                if let checkIn = todaysCheckIn {
                    Text(checkIn.feeling.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("How do you feel today?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(todaysCheckIn == nil ? "Check In" : "Update") {
                isCheckInPresented = true
            }
            .buttonStyle(.bordered)
        }
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    // MARK: - Recommendation

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Text("Today's Recommendation")
                .font(.headline)
            recommendationContent
            Button {
                startWorkout()
            } label: {
                Label("View Workout", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isScoreReady)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }

    @ViewBuilder
    private var recommendationContent: some View {
        if healthAccess.state == .connected, case .ready(_, let recommendation) = today.state {
            Label(
                "\(recommendation.recommendedDuration.minMinutes)–\(recommendation.recommendedDuration.maxMinutes) minutes",
                systemImage: "clock"
            )
            .font(.subheadline)
            Label {
                Text(recommendation.intensity.displayName)
            } icon: {
                Image(systemName: "gauge.with.needle")
            }
            .font(.subheadline)
            Label(activitiesText(recommendation.preferredActivities), systemImage: "figure.mixed.cardio")
                .font(.subheadline)
            if let plan = recommendation.rationaleFacts.last {
                Text(plan.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Your personalized workout will appear here once your Body Score is ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var isScoreReady: Bool {
        if healthAccess.state == .connected, case .ready = today.state {
            return true
        }
        return false
    }

    private func startWorkout() {
        guard let plan = today.makeWorkout() else { return }
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        presentedWorkout = workout
    }

    /// Handles an insight-page CTA: generates a validated workout from the
    /// action's parameters, falling back to the daily recommendation.
    private func startWorkout(for action: SuggestedAction) {
        guard let plan = today.makeWorkout(for: action) ?? today.makeWorkout() else { return }
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        presentedWorkout = workout
    }

    private func activitiesText(_ activities: [ActivityType]) -> String {
        activities
            .prefix(3)
            .map { String(localized: $0.displayName) }
            .formatted(.list(type: .and))
    }
}

#Preview("Mock data") {
    TodayView(
        healthAccess: HealthAccessModel(healthProvider: MockHealthProvider()),
        today: TodayModel(healthMetrics: MockHealthProvider())
    )
    .modelContainer(for: CheckIn.self, inMemory: true)
}

#Preview("Needs Health access") {
    TodayView(
        healthAccess: HealthAccessModel(healthProvider: MockHealthProvider(authorizationNeeded: true)),
        today: TodayModel(healthMetrics: MockHealthProvider())
    )
    .modelContainer(for: CheckIn.self, inMemory: true)
}
