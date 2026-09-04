import SwiftUI
import SwiftData

/// Three-tab shell: Path, Insights, and Workouts. Coach is presented contextually,
/// and profile + settings live behind the person icon on Path.
/// Presents onboarding until a completed profile exists.
struct MainTabView: View {
    @Query private var profiles: [UserProfile]
    @Query private var coachPreferences: [CoachPreference]
    @State private var isOnboardingPresented = false

    private let profileSync = WatchProfileSyncService.shared

    private var needsOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding != true
    }

    private var watchSyncFingerprint: String {
        guard let profile = profiles.first else {
            return "profile:none"
        }
        let coachPreference = coachPreferences.first
        return [
            profile.hasCompletedOnboarding.description,
            profile.goal.rawValue,
            profile.activityFrequency.rawValue,
            profile.preferredActivities.map(\.rawValue).joined(separator: ","),
            profile.equipment.map(\.rawValue).joined(separator: ","),
            profile.preferredWorkoutMinutes.description,
            coachPreference?.tone.rawValue ?? CoachTone.supportive.rawValue,
            coachPreference?.preferredWeekdays.map { String($0) }.joined(separator: ",") ?? "",
        ].joined(separator: "|")
    }

    var body: some View {
        TabView {
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                PathView()
            }
            Tab("Insights", systemImage: "sparkles") {
                InsightsTabView()
            }
            Tab("Workouts", systemImage: "figure.run") {
                WorkoutTabView()
            }
        }
        // task(id:) runs at appearance and on every change, so the cover
        // presents reliably on first launch and dismisses once a profile exists.
        .task(id: needsOnboarding) {
            isOnboardingPresented = needsOnboarding
        }
        .task(id: watchSyncFingerprint) {
            profileSync.publish(profile: profiles.first, coachPreference: coachPreferences.first)
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [UserProfile.self, CoachPreference.self, CheckIn.self, LifeStatus.self, GeneratedWorkout.self, WorkoutJournalEntry.self],
            inMemory: true
        )
}
