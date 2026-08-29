import SwiftUI
import SwiftData

/// Conversational coach per PRD 7.5: on-device AI with a deterministic
/// fallback, always grounded in derived context and constraints.
struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]

    @State private var coach: CoachModel
    @State private var draft = ""
    @State private var presentedWorkout: GeneratedWorkout?
    /// Messages whose offer was already saved, so the button flips to "Saved".
    @State private var savedOfferIDs: Set<ChatMessage.ID> = []
    @FocusState private var isDraftFocused: Bool

    init(coach: CoachModel = CoachModel()) {
        _coach = State(initialValue: coach)
    }

    private static let suggestions: [LocalizedStringResource] = [
        "Why is my score today?",
        "I only have 15 minutes",
        "Make today easier",
    ]

    private var todaysCheckIn: CheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                inputBar
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isDraftFocused {
                        keyboardDismissButton
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
            .sheet(item: $presentedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: BPSpacing.small) {
                    if coach.messages.isEmpty {
                        emptyState
                    }
                    ForEach(coach.messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    if coach.isResponding {
                        HStack {
                            ProgressView()
                                .padding(BPSpacing.small)
                            Spacer()
                        }
                        .accessibilityLabel("Coach is thinking")
                    }
                }
                .padding(BPSpacing.medium)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                dismissKeyboard()
            }
            .onChange(of: coach.messages.count) {
                if let last = coach.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BPSpacing.medium) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Ask about today's readiness, your score, or how to fit training into your day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ForEach(Self.suggestions.indices, id: \.self) { index in
                Button {
                    send(String(localized: Self.suggestions[index]))
                } label: {
                    Text(Self.suggestions[index])
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, BPSpacing.xLarge)
    }

    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: BPSpacing.xLarge)
            }
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Text(message.text)
                if message.source == .safety {
                    Label("Safety notice", systemImage: "exclamationmark.shield")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if message.source == .fallback {
                    if let reason = message.fallbackReason {
                        Label("Basic guidance — \(reason)", systemImage: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Basic guidance — on-device AI unavailable", systemImage: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let workout = message.workout {
                    workoutOfferCard(workout, messageID: message.id)
                }
            }
            .padding(BPSpacing.small + BPSpacing.xSmall)
            .background(
                message.isUser ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.regularMaterial),
                in: .rect(cornerRadius: BPCornerRadius.control)
            )
            if !message.isUser {
                Spacer(minLength: BPSpacing.xLarge)
            }
        }
    }

    // MARK: - Workout offer

    /// Generator-validated workout attached to a coach reply: accept it now
    /// or keep it in the Workout tab for later.
    private func workoutOfferCard(_ workout: PlannedWorkout, messageID: ChatMessage.ID) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.small) {
            Divider()
            Text(workout.title)
                .font(.subheadline.weight(.semibold))
            Label(
                "\(workout.totalMinutes) minutes · \(String(localized: workout.intensity.displayName))",
                systemImage: "figure.mixed.cardio"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            HStack(spacing: BPSpacing.small) {
                Button {
                    viewWorkout(workout)
                } label: {
                    Label("View details", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)

                if savedOfferIDs.contains(messageID) {
                    Label("Saved for later", systemImage: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        saveWorkout(workout, messageID: messageID)
                    } label: {
                        Label("Save for later", systemImage: "bookmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline)
        }
    }

    private func viewWorkout(_ plan: PlannedWorkout) {
        dismissKeyboard()
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        presentedWorkout = workout
    }

    private func saveWorkout(_ plan: PlannedWorkout, messageID: ChatMessage.ID) {
        dismissKeyboard()
        let workout = GeneratedWorkout(plan: plan)
        modelContext.insert(workout)
        savedOfferIDs.insert(messageID)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: BPSpacing.small) {
            TextField("Ask your coach", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($isDraftFocused)
                .submitLabel(.send)
                .onSubmit {
                    send(draft)
                }
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Send message")
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coach.isResponding)
            if isDraftFocused {
                keyboardDismissButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(BPSpacing.medium)
        .background(.bar)
        .animation(.default, value: isDraftFocused)
    }

    private var keyboardDismissButton: some View {
        Button {
            dismissKeyboard()
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Dismiss keyboard")
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !coach.isResponding else { return }

        draft = ""
        dismissKeyboard()
        Task {
            await coach.send(trimmed, profile: profiles.first, checkIn: todaysCheckIn)
        }
    }

    private func dismissKeyboard() {
        isDraftFocused = false
    }
}

#Preview("Mock data") {
    CoachView(
        coach: CoachModel(
            healthMetrics: MockHealthProvider(),
            coachService: CoachService(primary: nil)
        )
    )
    .modelContainer(for: CheckIn.self, inMemory: true)
}
