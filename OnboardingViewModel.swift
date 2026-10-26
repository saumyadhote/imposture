import Foundation
import Observation

@MainActor @Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case focus
        case preferences
        case reminder
    }

    private(set) var step: Step = .welcome
    var draft = UserPreferences()
    private(set) var isRequestingReminder = false
    /// Set when the person turned reminders on but notifications are blocked.
    private(set) var reminderDenied = false

    private let reminders: ReminderScheduling

    init(reminders: ReminderScheduling) {
        self.reminders = reminders
    }

    var stepNumber: Int { step.rawValue + 1 }
    var stepCount: Int { Step.allCases.count }
    var canGoBack: Bool { step != .welcome }
    var isLastStep: Bool { step == .reminder }

    func goForward() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func toggleFocus(_ area: BodyArea) {
        if draft.focusAreas.contains(area) {
            draft.focusAreas.remove(area)
        } else {
            draft.focusAreas.insert(area)
        }
    }

    /// Asks for permission and schedules the reminder.
    /// Returns true when onboarding can finish.
    func enableReminder() async -> Bool {
        isRequestingReminder = true
        defer { isRequestingReminder = false }
        guard await reminders.requestAuthorization() else {
            draft.remindersEnabled = false
            reminderDenied = true
            return false
        }
        do {
            try await reminders.scheduleDailyReminder(at: draft.reminderTime)
            draft.remindersEnabled = true
            return true
        } catch {
            draft.remindersEnabled = false
            reminderDenied = true
            return false
        }
    }

    func skipReminder() {
        draft.remindersEnabled = false
    }
}
