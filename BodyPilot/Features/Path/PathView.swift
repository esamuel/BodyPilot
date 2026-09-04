import SwiftData
import SwiftUI
import UIKit

struct PathView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]
    @Query(sort: \LifeStatus.startDate, order: .reverse) private var lifeStatuses: [LifeStatus]
    @Query private var journalEntries: [WorkoutJournalEntry]

    @State private var healthAccess: HealthAccessModel
    @State private var model: PathModel
    @State private var selectedWindow: CorridorWindow = .tenDays
    @State private var isLifeStatusPresented = false
    @State private var isCoachPresented = false
    @State private var isProfilePresented = false
    @State private var presentedWorkout: GeneratedWorkout?

    init(
        healthAccess: HealthAccessModel = HealthAccessModel(),
        model: PathModel = PathModel()
    ) {
        _healthAccess = State(initialValue: healthAccess)
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: BPSpacing.large) {
                    salutationTitle
                        .font(.largeTitle.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    if shouldShowHealthAccess {
                        PathHealthAccessCard(
                            state: healthAccess.state,
                            onConnect: connectHealth,
                            onRetry: refreshHealthAccess
                        )
                    } else if model.isLoading {
                        ProgressView()
                            .padding(BPSpacing.xLarge)
                            .accessibilityLabel("Loading your activity corridor")
                    } else if let errorMessage = model.errorMessage {
                        PathErrorCard(message: errorMessage, onRetry: refresh)
                    } else {
                        pathContent
                    }
                }
                .padding(BPSpacing.medium)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isProfilePresented = true
                    } label: {
                        if let avatarData = profiles.first?.avatarImageData,
                           let avatar = UIImage(data: avatarData) {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(.circle)
                        } else {
                            Label("Your Profile", systemImage: "person.crop.circle")
                        }
                    }
                    .accessibilityLabel("Your Profile")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCoachPresented = true
                    } label: {
                        Label("Ask Coach", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            .task(id: refreshFingerprint) {
                if model.requiresHealthAccess {
                    await healthAccess.refresh()
                }
                if !model.requiresHealthAccess || healthAccess.state == .connected {
                    await refreshModel()
                } else {
                    modelFinishedWaiting()
                }
            }
            .sheet(isPresented: $isLifeStatusPresented) {
                LifeStatusSheet(
                    activeStatus: activeLifeStatus,
                    onSave: saveLifeStatus,
                    onEnd: endLifeStatus
                )
            }
            .sheet(isPresented: $isCoachPresented) {
                CoachView()
            }
            .sheet(isPresented: $isProfilePresented) {
                UserDataView(
                    onSaveLifeStatus: saveLifeStatus,
                    onEndLifeStatus: endLifeStatus
                )
            }
            .sheet(item: $presentedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    @ViewBuilder
    private var pathContent: some View {
        if let corridor = model.corridor(for: selectedWindow),
           let today = corridor.today {
            PathStatusCard(
                day: today,
                streak: model.streak,
                hasWorkoutHistory: !model.recentWorkouts.isEmpty,
                activeLifeStatus: activeLifeStatus?.kind
            )
            PathCorridorCard(
                corridor: corridor,
                selectedWindow: $selectedWindow
            )
            LifeStatusCard(
                activeKind: activeLifeStatus?.kind,
                onTap: { isLifeStatusPresented = true }
            )
            if let recommendation = model.recommendation {
                DailySuggestionCard(
                    recommendation: recommendation,
                    onStart: startWorkout
                )
            }
            VitalsCard(vitals: model.vitals)
            if let weeklyRecap = model.recaps.first(where: { $0.period == .week }) {
                RecapPreviewCard(recap: weeklyRecap)
            }
        } else {
            ContentUnavailableView(
                "Your path is taking shape",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                description: Text("Record activity and recovery signals to build your personal corridor.")
            )
        }
    }

    /// Time-of-day greeting, personalized with the profile name when available.
    private var salutationTitle: Text {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profiles.first?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            switch hour {
            case 5..<12: return Text("Good morning, \(name)")
            case 12..<17: return Text("Good afternoon, \(name)")
            default: return Text("Good evening, \(name)")
            }
        }
        switch hour {
        case 5..<12: return Text("Good morning")
        case 12..<17: return Text("Good afternoon")
        default: return Text("Good evening")
        }
    }

    private var todaysCheckIn: CheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private var activeLifeStatus: LifeStatus? {
        LifeStatusResolver.activeStatus(in: lifeStatuses, at: .now)
    }

    private var shouldShowHealthAccess: Bool {
        guard model.requiresHealthAccess else { return false }
        return healthAccess.state != .connected && healthAccess.state != .checking
    }

    private var refreshFingerprint: String {
        let checkIn = todaysCheckIn?.date.timeIntervalSince1970.description ?? "none"
        let profile = profiles.first?.createdAt.timeIntervalSince1970.description ?? "none"
        let statuses = lifeStatuses.map {
            "\($0.id.uuidString):\($0.startDate.timeIntervalSince1970):\($0.endDate?.timeIntervalSince1970 ?? -1)"
        }.joined(separator: "|")
        let journal = journalEntries.map {
            "\($0.workoutID.uuidString):\($0.perceivedExertion ?? 0):\($0.updatedAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        return "\(checkIn)-\(profile)-\(statuses)-\(journal)"
    }

    private func refreshModel() async {
        await model.refresh(
            checkIn: todaysCheckIn,
            profile: profiles.first,
            lifeStatuses: lifeStatuses,
            journalEntries: journalEntries
        )
    }

    private func refresh() {
        Task {
            await refreshModel()
        }
    }

    private func refreshHealthAccess() {
        Task {
            await healthAccess.refresh()
            if healthAccess.state == .connected {
                await refreshModel()
            }
        }
    }

    private func connectHealth() {
        Task {
            await healthAccess.connect()
            if healthAccess.state == .connected {
                await refreshModel()
            }
        }
    }

    private func modelFinishedWaiting() {
        // The health-access card owns this state; no HealthKit query should run yet.
    }

    private func saveLifeStatus(kind: LifeStatusKind, start: Date, end: Date?) {
        modelContext.insert(LifeStatus(kind: kind, startDate: start, endDate: end))
        if start <= .now && end.map({ .now <= $0 }) != false {
            NotificationService().suspendForActiveLifeStatus()
        }
    }

    private func endLifeStatus(_ status: LifeStatus) {
        let calendar = Calendar.current
        if calendar.isDateInToday(status.startDate) {
            modelContext.delete(status)
        } else {
            status.endDate = calendar.date(byAdding: .day, value: -1, to: .now)
        }
    }

    private func startWorkout() {
        guard let plan = model.makeWorkout() else { return }
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        presentedWorkout = workout
    }
}

private struct PathStatusCard: View {
    let day: CorridorDay
    let streak: StreakResult
    let hasWorkoutHistory: Bool
    let activeLifeStatus: LifeStatusKind?

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            HStack(alignment: .top, spacing: BPSpacing.medium) {
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(day.state.displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(activeLifeStatus == nil ? day.state.tint : .secondary)
                }
                Spacer()
                PathStreakLabel(
                    streak: streak,
                    hasWorkoutHistory: hasWorkoutHistory
                )
            }

            if let activeLifeStatus {
                Label {
                    Text("Your corridor is paused while your status is \(Text(activeLifeStatus.displayName)).")
                } icon: {
                    Image(systemName: "pause.circle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if !hasWorkoutHistory {
                Text("Record a workout with Apple Watch or share workouts from Health to start your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if streak.count == 0 {
                Text("Reach today's healthy-load range to start your streak. Today will not count against you while it is still in progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if day.isRestRecommended {
                Text("Rest is inside your plan today. Taking it easy protects your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Follow today's healthy-load recommendation to extend your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct PathStreakLabel: View {
    let streak: StreakResult
    let hasWorkoutHistory: Bool

    var body: some View {
        Label {
            if !hasWorkoutHistory {
                Text("No workout data")
            } else if streak.count == 0 {
                Text("Start your streak")
            } else if streak.count == 1 {
                Text("1-day streak")
            } else {
                Text("\(streak.count)-day streak")
            }
        } icon: {
            Image(systemName: streak.isFrozen ? "pause.circle.fill" : "flame.fill")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(streak.isFrozen ? .secondary : BodyPilotColors.warningOrange)
    }
}

private struct PathCorridorCard: View {
    let corridor: ActivityCorridor
    @Binding var selectedWindow: CorridorWindow

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Activity Corridor")
                .font(.headline)

            Picker("Time range", selection: $selectedWindow) {
                Text("1 day").tag(CorridorWindow.day)
                Text("10 days").tag(CorridorWindow.tenDays)
                Text("30 days").tag(CorridorWindow.thirtyDays)
            }
            .pickerStyle(.segmented)

            CorridorChart(corridor: corridor)

            if corridor.confidence < 1 {
                Text("BodyPilot is still learning your usual training rhythm.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct LifeStatusCard: View {
    let activeKind: LifeStatusKind?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BPSpacing.medium) {
                Image(systemName: activeKind?.systemImage ?? "heart.text.square")
                    .font(.title2)
                    .foregroundStyle(activeKind == nil ? Color.routeTeal : Color.secondary)
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Text("Life Status")
                        .font(.headline)
                    if let activeKind {
                        Text(activeKind.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Pause pressure for illness, injury, a break, or vacation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct DailySuggestionCard: View {
    let recommendation: DailyRecommendation
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                    Text(verbatim: "BodyPilot")
                        .font(.headline)
                    Text(recommendation.dailySuggestion.displayName)
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Color.routeTeal)
            }

            Label {
                Text(
                    "\(recommendation.recommendedDuration.minMinutes)–\(recommendation.recommendedDuration.maxMinutes) minutes"
                )
            } icon: {
                Image(systemName: "clock")
            }
            .font(.subheadline)

            Button(action: onStart) {
                Label("View Workout", systemImage: "figure.run")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct VitalsCard: View {
    let vitals: PathVitals

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: BPSpacing.medium)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BPSpacing.medium) {
            Text("Today’s Vitals")
                .font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: BPSpacing.medium) {
                VitalItem(
                    title: "Sleep",
                    value: vitals.sleepHours.map {
                        Duration.seconds($0 * 3600).formatted(
                            .units(allowed: [.hours, .minutes], width: .abbreviated)
                        )
                    } ?? "—",
                    systemImage: "moon.fill"
                )
                VitalItem(
                    title: "Resting HR",
                    value: vitals.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—",
                    systemImage: "heart.fill"
                )
                VitalItem(
                    title: "HRV",
                    value: vitals.hrvSDNN.map { "\(Int($0.rounded())) ms" } ?? "—",
                    systemImage: "waveform.path.ecg"
                )
                VitalItem(
                    title: "Steps",
                    value: vitals.steps.map { Int($0.rounded()).formatted() } ?? "—",
                    systemImage: "figure.walk"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BPSpacing.large)
        .background(.regularMaterial, in: .rect(cornerRadius: BPCornerRadius.card))
    }
}

private struct VitalItem: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.routeTeal)
        }
    }
}

private struct PathHealthAccessCard: View {
    let state: HealthAccessModel.ConnectionState
    let onConnect: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connect Apple Health", systemImage: "heart.text.square")
        } description: {
            switch state {
            case .unavailable:
                Text("Health data is not available on this device.")
            case .failed(let message):
                Text(message)
            default:
                Text("Your activity corridor uses workouts, heart rate, sleep, and recovery trends.")
            }
        } actions: {
            if state == .needsRequest {
                Button("Connect Apple Health", action: onConnect)
                    .buttonStyle(.borderedProminent)
            } else if case .failed = state {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.top, BPSpacing.xLarge)
    }
}

private struct PathErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t load your path", systemImage: "arrow.clockwise")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        }
    }
}

#Preview("English") {
    PathView(
        model: PathModel(
            healthMetrics: MockHealthProvider(),
            requiresHealthAccess: false
        )
    )
    .modelContainer(
        for: [UserProfile.self, CheckIn.self, LifeStatus.self, GeneratedWorkout.self, CoachPreference.self, WorkoutJournalEntry.self],
        inMemory: true
    )
}

#Preview("Hebrew RTL") {
    PathView(
        model: PathModel(
            healthMetrics: MockHealthProvider(),
            requiresHealthAccess: false
        )
    )
    .modelContainer(
        for: [UserProfile.self, CheckIn.self, LifeStatus.self, GeneratedWorkout.self, CoachPreference.self, WorkoutJournalEntry.self],
        inMemory: true
    )
    .environment(\.locale, Locale(identifier: "he"))
    .environment(\.layoutDirection, .rightToLeft)
}
