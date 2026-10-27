#if DEBUG
import Foundation

/// In-memory stand-ins so previews never touch real user data.
final class PreviewHistoryStore: SessionHistoryStoring {
    var sessions: [CompletedSession]

    init(sessions: [CompletedSession] = []) {
        self.sessions = sessions
    }

    func fetchAll() throws -> [CompletedSession] { sessions.sorted { $0.endedAt > $1.endedAt } }
    func add(_ session: CompletedSession) throws { sessions.append(session) }
    func deleteAll() throws { sessions.removeAll() }
}

final class PreviewPreferencesStore: PreferencesStoring {
    var preferences: UserPreferences

    init(_ preferences: UserPreferences) {
        self.preferences = preferences
    }

    func load() -> UserPreferences { preferences }
    func save(_ preferences: UserPreferences) { self.preferences = preferences }
}

final class PreviewSnapshotStore: SessionSnapshotStoring {
    var snapshot: SessionSnapshot?

    func load() -> SessionSnapshot? { snapshot }
    func save(_ snapshot: SessionSnapshot) { self.snapshot = snapshot }
    func clear() { snapshot = nil }
}

final class PreviewAssessmentStore: PostureAssessmentStoring {
    var assessments: [PostureAssessment]

    init(assessments: [PostureAssessment] = []) {
        self.assessments = assessments
    }

    func fetchAll() throws -> [PostureAssessment] { assessments.sorted { $0.endedAt > $1.endedAt } }
    func add(_ assessment: PostureAssessment) throws { assessments.append(assessment) }
    func deleteAll() throws { assessments.removeAll() }
}

struct PreviewReminderService: ReminderScheduling {
    func requestAuthorization() async -> Bool { true }
    func scheduleDailyReminder(at time: ReminderTime) async throws {}
    func cancelReminders() {}
}

extension AppModel {
    static func preview(onboarded: Bool = true, withHistory: Bool = true) -> AppModel {
        var preferences = UserPreferences()
        preferences.hasCompletedOnboarding = onboarded
        preferences.focusAreas = [.neck, .upperBack]

        let now = Date()
        // Days 1 and 2 of the programme, done on earlier days. Preview data only.
        let sessions: [CompletedSession] = withHistory ? [(2, 1), (1, 2)].map { daysAgo, day in
            let end = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return CompletedSession(
                id: UUID(),
                routineID: "day-\(day)",
                title: "Day \(day)",
                startedAt: end.addingTimeInterval(-420),
                endedAt: end,
                activeSeconds: 380,
                exercisesCompleted: 4,
                exercisesTotal: 4,
                reachedEnd: true
            )
        } : []

        let model = AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: PreviewPreferencesStore(preferences),
            historyStore: PreviewHistoryStore(sessions: sessions),
            snapshotStore: PreviewSnapshotStore(),
            assessmentStore: PreviewAssessmentStore(assessments: withHistory ? [.previewSample()] : []),
            reminders: PreviewReminderService()
        )
        model.load()
        return model
    }
}

extension SessionViewModel {
    static func preview() -> SessionViewModel {
        let model = AppModel.preview()
        let library = model.library
        let routine = library?.routine(id: "day-1")
        let plan = routine.flatMap(model.plan(for:)) ?? SessionPlan(routineID: nil, title: "Preview", exercises: [])
        return SessionViewModel(plan: plan)
    }
}
#endif
