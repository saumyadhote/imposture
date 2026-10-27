import Foundation
import UserNotifications

protocol ReminderScheduling {
    /// Asks for notification permission if needed. Returns whether reminders can be delivered.
    func requestAuthorization() async -> Bool
    func scheduleDailyReminder(at time: ReminderTime) async throws
    func cancelReminders()
}

/// Schedules one repeating local notification. Nothing leaves the device.
struct LocalReminderService: ReminderScheduling {
    private static let identifier = "imposture.dailyReminder"
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    func scheduleDailyReminder(at time: ReminderTime) async throws {
        cancelReminders()
        let content = UNMutableNotificationContent()
        content.title = "Time for a movement break"
        content.body = "A few minutes of gentle movement, whenever you're ready."
        content.sound = .default

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancelReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
