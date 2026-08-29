import SwiftUI
import SwiftData

@main
struct BodyPilotWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(BodyPilotModelContainer.shared)
    }
}
