import Foundation
import Observation

#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif

private enum WatchProfileSyncKeys {
    static let profileContext = "bodyPilotProfilePreferences"
    static let readinessContext = "bodyPilotReadinessSummary"
    static let profileDefaults = "com.bodypilot.watchProfilePreferences"
    static let readinessDefaults = "com.bodypilot.watchReadinessSummary"
}

struct SyncedProfilePreferences: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let goal: FitnessGoal
    let activityFrequency: ActivityFrequency
    let preferredActivities: [ActivityType]
    let equipment: [EquipmentType]
    let preferredWorkoutMinutes: Int
    let coachTone: CoachTone
    let preferredWeekdays: [Int]
    let updatedAt: Date

    static let `default` = SyncedProfilePreferences(
        schemaVersion: 1,
        goal: .generalFitness,
        activityFrequency: .occasional,
        preferredActivities: [.walking],
        equipment: [.none],
        preferredWorkoutMinutes: 30,
        coachTone: .supportive,
        preferredWeekdays: [],
        updatedAt: .distantPast
    )

    init(
        schemaVersion: Int,
        goal: FitnessGoal,
        activityFrequency: ActivityFrequency,
        preferredActivities: [ActivityType],
        equipment: [EquipmentType],
        preferredWorkoutMinutes: Int,
        coachTone: CoachTone,
        preferredWeekdays: [Int],
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.goal = goal
        self.activityFrequency = activityFrequency
        self.preferredActivities = preferredActivities
        self.equipment = equipment
        self.preferredWorkoutMinutes = preferredWorkoutMinutes
        self.coachTone = coachTone
        self.preferredWeekdays = preferredWeekdays
        self.updatedAt = updatedAt
    }

    @MainActor
    init(profile: UserProfile, coachPreference: CoachPreference?, updatedAt: Date = .now) {
        self.init(
            schemaVersion: 1,
            goal: profile.goal,
            activityFrequency: profile.activityFrequency,
            preferredActivities: profile.preferredActivities,
            equipment: profile.equipment,
            preferredWorkoutMinutes: profile.preferredWorkoutMinutes,
            coachTone: coachPreference?.tone ?? .supportive,
            preferredWeekdays: coachPreference?.preferredWeekdays ?? [],
            updatedAt: updatedAt
        )
    }

    var readinessPreferences: ReadinessPreferences {
        ReadinessPreferences(
            goal: goal,
            preferredActivities: preferredActivities,
            preferredWorkoutMinutes: preferredWorkoutMinutes,
            equipment: equipment
        )
    }

    func hasSameContent(as other: SyncedProfilePreferences) -> Bool {
        schemaVersion == other.schemaVersion
            && goal == other.goal
            && activityFrequency == other.activityFrequency
            && preferredActivities == other.preferredActivities
            && equipment == other.equipment
            && preferredWorkoutMinutes == other.preferredWorkoutMinutes
            && coachTone == other.coachTone
            && preferredWeekdays == other.preferredWeekdays
    }
}

struct SyncedReadinessSummary: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let bodyScore: Int
    let confidence: Double
    let readiness: ReadinessLevel
    let recommendedMinMinutes: Int
    let recommendedMaxMinutes: Int
    let intensity: WorkoutIntensity
    let preferredActivities: [ActivityType]
    let computedAt: Date

    init(
        schemaVersion: Int,
        bodyScore: Int,
        confidence: Double,
        readiness: ReadinessLevel,
        recommendedMinMinutes: Int,
        recommendedMaxMinutes: Int,
        intensity: WorkoutIntensity,
        preferredActivities: [ActivityType],
        computedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.bodyScore = bodyScore
        self.confidence = confidence
        self.readiness = readiness
        self.recommendedMinMinutes = recommendedMinMinutes
        self.recommendedMaxMinutes = recommendedMaxMinutes
        self.intensity = intensity
        self.preferredActivities = preferredActivities
        self.computedAt = computedAt
    }

    init(score: BodyScoreResult, recommendation: DailyRecommendation) {
        self.init(
            schemaVersion: 1,
            bodyScore: score.score,
            confidence: score.confidence,
            readiness: score.readiness,
            recommendedMinMinutes: recommendation.recommendedDuration.minMinutes,
            recommendedMaxMinutes: recommendation.recommendedDuration.maxMinutes,
            intensity: recommendation.intensity,
            preferredActivities: recommendation.preferredActivities,
            computedAt: score.computedAt
        )
    }

    var isStale: Bool {
        computedAt < Date.now.addingTimeInterval(-12 * 60 * 60)
    }
}

@MainActor
@Observable
final class WatchProfileSyncService: NSObject {
    static let shared = WatchProfileSyncService()

    private(set) var preferences: SyncedProfilePreferences
    private(set) var readinessSummary: SyncedReadinessSummary?
    private(set) var lastSyncError: String?

    private var contextNeedsFlush = false

    #if canImport(WatchConnectivity)
    private var session: WCSession?
    #endif

    private override init() {
        preferences = Self.loadStoredPreferences() ?? .default
        readinessSummary = Self.loadStoredReadinessSummary()
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }

        let defaultSession = WCSession.default
        if session !== defaultSession {
            session = defaultSession
            defaultSession.delegate = self
        }

        switch defaultSession.activationState {
        case .notActivated:
            defaultSession.activate()
        case .activated:
            handleActivatedSession()
        case .inactive:
            break
        @unknown default:
            break
        }
        #endif
    }

    func publish(profile: UserProfile?, coachPreference: CoachPreference?) {
        activate()

        #if os(iOS) && canImport(WatchConnectivity)
        guard let profile, profile.hasCompletedOnboarding else { return }

        let nextPreferences = SyncedProfilePreferences(profile: profile, coachPreference: coachPreference)
        if preferences.hasSameContent(as: nextPreferences) {
            flushPendingContext()
            return
        }

        apply(nextPreferences)
        contextNeedsFlush = true
        flushPendingContext()
        #endif
    }

    func publish(score: BodyScoreResult, recommendation: DailyRecommendation) {
        activate()

        #if os(iOS) && canImport(WatchConnectivity)
        let summary = SyncedReadinessSummary(score: score, recommendation: recommendation)
        guard readinessSummary != summary else {
            flushPendingContext()
            return
        }

        apply(summary)
        contextNeedsFlush = true
        flushPendingContext()
        #endif
    }

    private func handleActivatedSession() {
        #if canImport(WatchConnectivity)
        apply(applicationContext: session?.receivedApplicationContext ?? [:])
        flushPendingContext()
        #endif
    }

    private func apply(applicationContext: [String: Any]) {
        apply(profileData: applicationContext[WatchProfileSyncKeys.profileContext] as? Data)
        apply(readinessData: applicationContext[WatchProfileSyncKeys.readinessContext] as? Data)
    }

    private func apply(profileData: Data?) {
        guard let profileData else { return }
        do {
            apply(try JSONDecoder().decode(SyncedProfilePreferences.self, from: profileData))
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func apply(readinessData: Data?) {
        guard let readinessData else { return }
        do {
            apply(try JSONDecoder().decode(SyncedReadinessSummary.self, from: readinessData))
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func apply(_ preferences: SyncedProfilePreferences) {
        self.preferences = preferences
        store(preferences)
    }

    private func apply(_ readinessSummary: SyncedReadinessSummary) {
        self.readinessSummary = readinessSummary
        store(readinessSummary)
    }

    private func flushPendingContext() {
        #if os(iOS) && canImport(WatchConnectivity)
        guard contextNeedsFlush,
              let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }

        do {
            var context: [String: Any] = [
                WatchProfileSyncKeys.profileContext: try JSONEncoder().encode(preferences)
            ]
            if let readinessSummary {
                context[WatchProfileSyncKeys.readinessContext] = try JSONEncoder().encode(readinessSummary)
            }
            try session.updateApplicationContext(context)
            contextNeedsFlush = false
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
        #endif
    }

    private func store(_ preferences: SyncedProfilePreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: WatchProfileSyncKeys.profileDefaults)
    }

    private func store(_ readinessSummary: SyncedReadinessSummary) {
        guard let data = try? JSONEncoder().encode(readinessSummary) else { return }
        UserDefaults.standard.set(data, forKey: WatchProfileSyncKeys.readinessDefaults)
    }

    private static func loadStoredPreferences() -> SyncedProfilePreferences? {
        guard let data = UserDefaults.standard.data(forKey: WatchProfileSyncKeys.profileDefaults) else { return nil }
        return try? JSONDecoder().decode(SyncedProfilePreferences.self, from: data)
    }

    private static func loadStoredReadinessSummary() -> SyncedReadinessSummary? {
        guard let data = UserDefaults.standard.data(forKey: WatchProfileSyncKeys.readinessDefaults) else { return nil }
        return try? JSONDecoder().decode(SyncedReadinessSummary.self, from: data)
    }
}

#if canImport(WatchConnectivity)
extension WatchProfileSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                self.lastSyncError = error.localizedDescription
                return
            }
            if activationState == .activated {
                self.handleActivatedSession()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let profileData = applicationContext["bodyPilotProfilePreferences"] as? Data
        let readinessData = applicationContext["bodyPilotReadinessSummary"] as? Data
        Task { @MainActor in
            self.apply(profileData: profileData)
            self.apply(readinessData: readinessData)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.flushPendingContext()
        }
    }
    #endif
}
#endif
