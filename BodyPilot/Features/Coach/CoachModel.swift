import Foundation
import Observation

/// One rendered chat bubble.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let source: CoachResponse.Source?
    let fallbackReason: String?
    /// A deterministic, generator-validated workout the user can accept or
    /// save. Attached by CoachModel — never produced by the language model.
    var workout: PlannedWorkout?

    init(
        isUser: Bool,
        text: String,
        source: CoachResponse.Source?,
        fallbackReason: String? = nil,
        workout: PlannedWorkout? = nil
    ) {
        self.isUser = isUser
        self.text = text
        self.source = source
        self.fallbackReason = fallbackReason
        self.workout = workout
    }
}

/// Drives the Coach chat: builds fresh derived context per question via the
/// shared readiness pipeline and asks the coach service.
@MainActor
@Observable
final class CoachModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false
    private(set) var lastSource: CoachResponse.Source?

    private let readiness: ReadinessService
    private let coachService: CoachService
    private let workoutGenerator: WorkoutGenerator
    private let contextBuilder = AIContextBuilder()

    init(
        healthMetrics: any HealthMetricsProviding = HealthKitClient(),
        coachService: CoachService = CoachService(primary: FoundationModelCoach()),
        workoutGenerator: WorkoutGenerator = WorkoutGenerator()
    ) {
        self.readiness = ReadinessService(healthMetrics: healthMetrics)
        self.coachService = coachService
        self.workoutGenerator = workoutGenerator
    }

    func send(_ text: String, profile: UserProfile?, checkIn: CheckIn?, now: Date = .now) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        messages.append(ChatMessage(isUser: true, text: trimmed, source: nil))
        isResponding = true
        defer { isResponding = false }

        let preferences = ReadinessPreferences(profile: profile)
        // When health queries fail, the coach still answers from a minimal context.
        let snapshot = try? await readiness.snapshot(
            preferences: preferences,
            feeling: checkIn?.feeling,
            soreness: checkIn?.soreness ?? [],
            now: now
        )
        let emptyDeltas = BaselineDeltas(sleepDelta: nil, hrvDelta: nil, restingHRDeltaBPM: nil)
        let score = snapshot?.score ?? BodyScoreEngine().computeScore(
            from: BodyScoreInput(
                deltas: emptyDeltas,
                recentLoad: nil,
                recoveryConsistency: nil,
                feeling: checkIn?.feeling,
                date: now
            )
        )
        let context = contextBuilder.makeContext(
            score: score,
            deltas: snapshot?.deltas ?? emptyDeltas,
            recentLoad: snapshot?.recentLoad ?? .rest,
            feeling: checkIn?.feeling,
            goal: preferences.goal,
            equipment: preferences.equipment,
            preferredActivities: preferences.preferredActivities,
            preferredWorkoutMinutes: preferences.preferredWorkoutMinutes
        )
        let request = CoachRequest(
            message: trimmed,
            context: context,
            constraints: snapshot?.recommendation.constraints ?? [],
            profile: .dailyCoach
        )
        let response = await coachService.respond(to: request)
        lastSource = response.source

        var workout: PlannedWorkout?
        // Never attach a workout to a safety response.
        if response.source != .safety, let snapshot, Self.wantsWorkout(trimmed) {
            workout = workoutOffer(for: trimmed, snapshot: snapshot, preferences: preferences)
        }
        var reply = ChatMessage(
            isUser: false,
            text: workout.map(Self.workoutReadyText) ?? response.text,
            source: response.source,
            fallbackReason: response.fallbackReason
        )
        reply.workout = workout
        messages.append(reply)
    }

    // MARK: - Deterministic workout offers

    /// English keyword screen for training intent. Deliberately simple and
    /// deterministic — the language model has no say in whether an offer appears.
    static func wantsWorkout(_ message: String) -> Bool {
        let lowered = message.lowercased()
        let keywords = [
            "workout", "train", "session", "exercise", "walk", "home",
            "minute", "min", "easier", "easy", "harder", "gentle", "stretch",
            "training", "routine", "plan", "detailed", "strength", "mobility",
            "balance", "cardio", "run", "ride",
            "אימון", "אימונים", "להתאמן", "תוכנית", "תרגיל", "תרגילים",
            "דקות", "הליכה", "ריצה", "כוח", "מתיחות", "קל", "קשה",
        ]
        return keywords.contains { lowered.contains($0) }
    }

    /// First plausible duration mentioned in the message, e.g. "I only have 15 minutes".
    static func requestedMinutes(in message: String) -> Int? {
        let numbers = message
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        return numbers.first { (5...240).contains($0) }
    }

    /// One intensity band gentler, for "make it easier" style requests.
    private static func eased(_ intensity: WorkoutIntensity) -> WorkoutIntensity {
        switch intensity {
        case .hard: .moderate
        case .moderate: .light
        case .light, .recovery: .recovery
        }
    }

    private static func workoutReadyText(for _: PlannedWorkout) -> String {
        String(localized: "I built a step-by-step workout below. Open it to follow each movement, duration, and coaching cue.")
    }

    /// Builds a validated offer from today's deterministic recommendation.
    /// The message may only tighten it (shorter, gentler) — never exceed it.
    private func workoutOffer(
        for message: String,
        snapshot: ReadinessSnapshot,
        preferences: ReadinessPreferences
    ) -> PlannedWorkout? {
        let lowered = message.lowercased()
        let wantsEasier = ["easier", "easy", "gentle", "tired"].contains { lowered.contains($0) }
        let recommendation = snapshot.recommendation
        let adjusted = DailyRecommendation(
            level: recommendation.level,
            recommendedDuration: recommendation.recommendedDuration,
            preferredActivities: recommendation.preferredActivities,
            intensity: wantsEasier ? Self.eased(recommendation.intensity) : recommendation.intensity,
            constraints: recommendation.constraints,
            rationaleFacts: recommendation.rationaleFacts
        )
        return try? workoutGenerator.generateWorkout(
            for: WorkoutRequest(
                recommendation: adjusted,
                goal: preferences.goal,
                equipment: preferences.equipment,
                timeLimitMinutes: Self.requestedMinutes(in: message)
            )
        )
    }
}
