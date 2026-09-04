import SwiftUI
import UIKit

/// App settings, reached from the Profile sheet. Pushed inside an existing
/// NavigationStack, so it provides only the list, not its own stack.
struct SettingsListView: View {
    @State private var isOnboardingPresented = false

    var body: some View {
        List {
            MePreferencesSection()
            MeOnboardingSection(isOnboardingPresented: $isOnboardingPresented)
            MeNotificationsSection()
            MeSubscriptionSection()
            MePrivacySection()
            MeAboutSection()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView {
                isOnboardingPresented = false
            }
        }
    }
}

private struct MeOnboardingSection: View {
    @Binding var isOnboardingPresented: Bool

    var body: some View {
        Section("Onboarding") {
            Button {
                isOnboardingPresented = true
            } label: {
                Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

private struct MePreferencesSection: View {
    var body: some View {
        Section("Preferences") {
            NavigationLink {
                ProfileEditorView()
            } label: {
                Label("Goals, Activities & Coaching", systemImage: "target")
            }
            NavigationLink {
                LanguageRegionSettingsView()
            } label: {
                Label("Language & Region", systemImage: "globe")
            }
        }
    }
}

private struct MeNotificationsSection: View {
    var body: some View {
        Section("Notifications") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("Readiness Reminder", systemImage: "sunrise")
            }
        }
    }
}

private struct MeSubscriptionSection: View {
    var body: some View {
        Section("Subscription") {
            NavigationLink {
                PaywallView()
            } label: {
                Label("BodyPilot Pro", systemImage: "sparkles")
            }
        }
    }
}

private struct MePrivacySection: View {
    var body: some View {
        Section("Privacy") {
            NavigationLink {
                HealthPermissionsSettingsView()
            } label: {
                Label("Health Permissions", systemImage: "heart.text.square")
            }
            NavigationLink {
                DataPrivacySettingsView()
            } label: {
                Label("Data & Privacy", systemImage: "lock")
            }
        }
    }
}

private struct MeAboutSection: View {
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        return [version, build].compactMap(\.self).joined(separator: " ")
    }

    var body: some View {
        Section("About") {
            NavigationLink {
                SafetyInformationView()
            } label: {
                Label("Safety Information", systemImage: "info.circle")
            }
            LabeledContent("Version") {
                Text(appVersion.isEmpty ? "—" : appVersion)
            }
        }
    }
}

private struct NotificationSettingsView: View {
    @State private var notifications = NotificationService()
    @State private var reminderTime = Date.now

    var body: some View {
        List {
            Section {
                Toggle(isOn: morningReminderBinding) {
                    Label("Morning readiness reminder", systemImage: "sunrise")
                }
                DatePicker(
                    "Reminder time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!notifications.isMorningReminderEnabled)
            } header: {
                Text("Reminder")
            } footer: {
                Text("BodyPilot sends one reminder at your chosen time.")
            }
            Section {
                OpenAppSettingsButton()
            }
        }
        .navigationTitle("Notifications")
        .task {
            await notifications.refresh()
            reminderTime = notifications.reminderTime
        }
        .onChange(of: reminderTime) { _, newValue in
            Task {
                await notifications.setReminderTime(newValue)
            }
        }
    }

    private var morningReminderBinding: Binding<Bool> {
        Binding {
            notifications.isMorningReminderEnabled
        } set: { enabled in
            Task {
                await notifications.setMorningReminder(enabled: enabled)
            }
        }
    }
}

private struct HealthPermissionsSettingsView: View {
    @State private var healthAccess = HealthAccessModel()

    var body: some View {
        List {
            Section("Status") {
                healthStatusContent
            }
            Section("Data BodyPilot Uses") {
                Label("Workouts and heart rate measure training load.", systemImage: "figure.run")
                Label("Sleep, HRV, and resting heart rate estimate recovery.", systemImage: "bed.double")
                Label("Check-ins improve today's recommendation.", systemImage: "checklist")
            }
            Section {
                if canRequestHealthAccess {
                    Button("Connect Apple Health") {
                        Task {
                            await healthAccess.connect()
                        }
                    }
                }
                OpenAppSettingsButton()
            } header: {
                Text("Manage Access")
            } footer: {
                Text("Apple Health permissions are controlled by iOS. You can change them in Settings.")
            }
        }
        .navigationTitle("Health Permissions")
        .task {
            await healthAccess.refresh()
        }
    }

    private var canRequestHealthAccess: Bool {
        switch healthAccess.state {
        case .needsRequest, .failed:
            true
        case .checking, .connected, .unavailable:
            false
        }
    }

    @ViewBuilder
    private var healthStatusContent: some View {
        switch healthAccess.state {
        case .checking:
            ProgressView()
                .accessibilityLabel("Checking Apple Health connection")
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .needsRequest:
            Label("Not Connected", systemImage: "heart.slash")
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("Health data isn't available on this device.")
                .foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading, spacing: BPSpacing.xSmall) {
                Label("Not Connected", systemImage: "exclamationmark.triangle")
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DataPrivacySettingsView: View {
    var body: some View {
        List {
            Section("On-device data") {
                Label("Health samples stay in Apple Health.", systemImage: "heart.text.square")
                Label("BodyPilot stores your profile, check-ins, and generated workouts on this device.", systemImage: "internaldrive")
                Label("AI features receive derived readiness facts, not raw HealthKit history.", systemImage: "sparkles")
            }
            Section("Apple Watch & Widgets") {
                Label("Apple Watch receives your preferences and latest Body Score through WatchConnectivity.", systemImage: "applewatch")
                Label("Widgets receive display-ready scores and recommendation text.", systemImage: "square.grid.2x2")
            }
            Section("Your control") {
                Text("Change Health permissions, notifications, and app language in iOS Settings.")
                    .foregroundStyle(.secondary)
                OpenAppSettingsButton()
            }
        }
        .navigationTitle("Data & Privacy")
    }
}

private struct LanguageRegionSettingsView: View {
    var body: some View {
        List {
            Section("Language") {
                Text("BodyPilot follows your device language. Hebrew is included for iPhone, Apple Watch, widgets, shortcuts, and permission text.")
                    .foregroundStyle(.secondary)
            }
            Section("Apple Watch") {
                Text("The Watch app has its own string catalog and follows the Apple Watch language settings.")
                    .foregroundStyle(.secondary)
            }
            Section {
                OpenAppSettingsButton()
            }
        }
        .navigationTitle("Language & Region")
    }
}

private struct SafetyInformationView: View {
    var body: some View {
        List {
            Section("Not medical advice") {
                Text("BodyPilot gives fitness guidance, not diagnosis or medical treatment.")
                    .foregroundStyle(.secondary)
            }
            Section("During workouts") {
                Label("Stop if you feel chest pain, dizziness, or unusual shortness of breath.", systemImage: "exclamationmark.triangle")
                Label("Choose an easier option when recovery signals are low.", systemImage: "gauge.with.needle")
                Label("Follow guidance from your clinician over app suggestions.", systemImage: "person.text.rectangle")
            }
            Section("Emergency") {
                Text("If symptoms feel urgent, contact local emergency services.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Safety Information")
    }
}

private struct OpenAppSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            openURL(settingsURL)
        } label: {
            Label("Open App Settings", systemImage: "gearshape")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsListView()
    }
}
