import Foundation
import Observation
import UserNotifications

/// Schedules the optional morning readiness reminder. Wording per PRD 12 —
/// inviting, never guilt-based.
@MainActor
@Observable
final class NotificationService {
    private static let morningIdentifier = "com.bodypilot.morningReadiness"
    private static let reminderHourKey = "com.bodypilot.morningReadiness.hour"
    private static let reminderMinuteKey = "com.bodypilot.morningReadiness.minute"
    private static let defaultReminderHour = 8
    private static let defaultReminderMinute = 0

    private(set) var isMorningReminderEnabled = false
    private(set) var reminderTime: Date
    private let center = UNUserNotificationCenter.current()

    init() {
        reminderTime = NotificationService.loadReminderTime()
    }

    static var defaultReminderTime: Date {
        date(hour: defaultReminderHour, minute: defaultReminderMinute)
    }

    func refresh() async {
        reminderTime = Self.loadReminderTime()
        let pending = await center.pendingNotificationRequests()
        isMorningReminderEnabled = pending.contains { $0.identifier == Self.morningIdentifier }
    }

    func setMorningReminder(enabled: Bool) async {
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.morningIdentifier])
            isMorningReminderEnabled = false
            return
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                isMorningReminderEnabled = false
                return
            }
            try await scheduleMorningReminder()
            isMorningReminderEnabled = true
        } catch {
            isMorningReminderEnabled = false
        }
    }

    func setReminderTime(_ date: Date) async {
        reminderTime = Self.normalizedTime(date)
        Self.storeReminderTime(reminderTime)
        guard isMorningReminderEnabled else { return }
        do {
            try await scheduleMorningReminder()
        } catch {
            isMorningReminderEnabled = false
        }
    }

    private func scheduleMorningReminder() async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningIdentifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Good morning")
        content.body = String(localized: "Your plan is ready when you are.")

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(
            UNNotificationRequest(identifier: Self.morningIdentifier, content: content, trigger: trigger)
        )
    }

    private static func loadReminderTime() -> Date {
        let defaults = UserDefaults.standard
        let hour = defaults.object(forKey: reminderHourKey) as? Int ?? defaultReminderHour
        let minute = defaults.object(forKey: reminderMinuteKey) as? Int ?? defaultReminderMinute
        return date(hour: hour, minute: minute)
    }

    private static func storeReminderTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(components.hour ?? defaultReminderHour, forKey: reminderHourKey)
        UserDefaults.standard.set(components.minute ?? defaultReminderMinute, forKey: reminderMinuteKey)
    }

    private static func normalizedTime(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Self.date(
            hour: components.hour ?? defaultReminderHour,
            minute: components.minute ?? defaultReminderMinute
        )
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
    }
}
