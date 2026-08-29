import SwiftUI
import SwiftData

@main
struct BodyPilotApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(BodyPilotModelContainer.shared)
    }
}
