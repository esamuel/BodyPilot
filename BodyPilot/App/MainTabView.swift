import SwiftUI
import SwiftData

/// Five-tab shell per PRD section 6: Today, Coach, Workout, Progress, Me.
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
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Coach", systemImage: "bubble.left.and.text.bubble.right.fill") {
                CoachView()
            }
            Tab("Workout", systemImage: "figure.run") {
                WorkoutTabView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }
            Tab("Me", systemImage: "person.crop.circle") {
                MeView()
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
        .modelContainer(for: [UserProfile.self, CoachPreference.self], inMemory: true)
}
