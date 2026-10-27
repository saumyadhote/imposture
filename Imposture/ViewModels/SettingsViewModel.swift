import Foundation
import Observation

/// Reminder handling for Settings. Preferences themselves are stored by AppModel.
@MainActor @Observable
final class SettingsViewModel {
    private(set) var reminderMessage: String?
    private(set) var isUpdatingReminder = false

    private let appModel: AppModel

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        reminderMessage = nil
        guard enabled else {
            appModel.reminders.cancelReminders()
            appModel.updatePreferences { $0.remindersEnabled = false }
            return
        }
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }
        guard await appModel.reminders.requestAuthorization() else {
            appModel.updatePreferences { $0.remindersEnabled = false }
            reminderMessage = "Notifications are off for imposture. You can allow them in the Settings app under Notifications."
            return
        }
        await schedule(appModel.preferences.reminderTime)
    }

    func setReminderTime(_ time: ReminderTime) async {
        appModel.updatePreferences { $0.reminderTime = time }
        guard appModel.preferences.remindersEnabled else { return }
        await schedule(time)
    }

    private func schedule(_ time: ReminderTime) async {
        do {
            try await appModel.reminders.scheduleDailyReminder(at: time)
            appModel.updatePreferences { $0.remindersEnabled = true }
        } catch {
            appModel.updatePreferences { $0.remindersEnabled = false }
            reminderMessage = "The reminder couldn't be set. Please try again."
        }
    }
}
