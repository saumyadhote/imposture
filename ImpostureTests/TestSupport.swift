import Foundation
@testable import Imposture

/// A clock tests can move forward by hand.
final class TestClock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.now = now
    }

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    var function: () -> Date { { self.now } }
}

enum Fixtures {
    static func exercise(
        _ id: String,
        duration: Int = 30,
        position: ExercisePosition = .seated,
        areas: [BodyArea] = [.neck],
        bothSides: Bool = false
    ) -> Exercise {
        Exercise(
            id: id,
            name: id.capitalized,
            summary: "Summary for \(id)",
            bodyAreas: areas,
            position: position,
            equipment: .none,
            durationSeconds: duration,
            repsGuide: "Slowly",
            bothSides: bothSides,
            illustration: id,
            illustrationDescription: "Illustration",
            steps: ["Step"],
            easier: [],
            cautions: []
        )
    }

    static func plan(_ exercises: [Exercise]) -> SessionPlan {
        SessionPlan(routineID: "test", title: "Test", exercises: exercises)
    }

    static let threeExercisePlan = plan([
        exercise("a", duration: 30),
        exercise("b", duration: 20),
        exercise("c", duration: 10),
    ])

    /// Tests run inside the app, so the main bundle holds the real content.
    static func bundledLibrary() throws -> ExerciseLibrary {
        try BundledExerciseLibraryService().loadLibrary()
    }
}

final class InMemoryHistoryStore: SessionHistoryStoring {
    var sessions: [CompletedSession] = []
    var failNextAdd = false

    func fetchAll() throws -> [CompletedSession] { sessions.sorted { $0.endedAt > $1.endedAt } }

    func add(_ session: CompletedSession) throws {
        if failNextAdd {
            failNextAdd = false
            throw CocoaError(.fileWriteUnknown)
        }
        sessions.append(session)
    }

    func deleteAll() throws { sessions.removeAll() }
}

final class InMemoryAssessmentStore: PostureAssessmentStoring {
    var assessments: [PostureAssessment] = []
    var failNextAdd = false

    func fetchAll() throws -> [PostureAssessment] { assessments.sorted { $0.endedAt > $1.endedAt } }

    func add(_ assessment: PostureAssessment) throws {
        if failNextAdd {
            failNextAdd = false
            throw CocoaError(.fileWriteUnknown)
        }
        assessments.append(assessment)
    }

    func deleteAll() throws { assessments.removeAll() }
}

final class InMemoryPreferencesStore: PreferencesStoring {
    var stored = UserPreferences()
    func load() -> UserPreferences { stored }
    func save(_ preferences: UserPreferences) { stored = preferences }
}

final class InMemorySnapshotStore: SessionSnapshotStoring {
    var snapshot: SessionSnapshot?
    func load() -> SessionSnapshot? { snapshot }
    func save(_ snapshot: SessionSnapshot) { self.snapshot = snapshot }
    func clear() { snapshot = nil }
}

final class MockReminders: ReminderScheduling {
    var allow = true
    var scheduled: [ReminderTime] = []
    var cancelCount = 0

    func requestAuthorization() async -> Bool { allow }
    func scheduleDailyReminder(at time: ReminderTime) async throws { scheduled.append(time) }
    func cancelReminders() { cancelCount += 1 }
}

struct FailingLibraryService: ExerciseLibraryProviding {
    func loadLibrary() throws -> ExerciseLibrary { throw ExerciseLibraryError.missingResource }
}
