import SwiftUI

/// Top-level Watch navigation per PRD: Today and Start Workout pages, replaced
/// by the live workout and summary screens while a session is running.
struct ContentView: View {
    @State private var sessionManager = WorkoutSessionManager()
    @State private var profileSync = WatchProfileSyncService.shared

    var body: some View {
        Group {
            switch sessionManager.phase {
            case .active, .paused:
                ActiveWorkoutView()
            case .summary:
                WorkoutSummaryView()
            case .idle, .failed:
                TabView {
                    NavigationStack {
                        WatchTodayView()
                    }
                    NavigationStack {
                        WatchStartWorkoutView()
                    }
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .environment(sessionManager)
        .task {
            profileSync.activate()
        }
    }
}

#Preview {
    ContentView()
}
