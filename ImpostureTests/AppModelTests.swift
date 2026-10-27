import Foundation
import Testing
@testable import Imposture

@MainActor
struct AppModelTests {
    let clock = TestClock()
    let history = InMemoryHistoryStore()
    let preferences = InMemoryPreferencesStore()
    let snapshots = InMemorySnapshotStore()
    let reminders = MockReminders()

    private func makeModel(
        library: ExerciseLibraryProviding = BundledExerciseLibraryService(),
        historyStore: SessionHistoryStoring? = nil
    ) -> AppModel {
        let model = AppModel(
            libraryService: library,
            preferencesStore: preferences,
            historyStore: historyStore ?? history,
            snapshotStore: snapshots,
            reminders: reminders,
            clock: clock.function
        )
        model.load()
        return model
    }

    @Test("loads bundled content and suggests a routine")
    func loadsLibrary() {
        let model = makeModel()
        #expect(model.loadState == .loaded)
        #expect(model.library?.exercises.count == 31)
        #expect(model.library?.programme.count == 10)
        #expect(model.todaysRoutine != nil)
    }

    @Test("the programme keeps its specified days and exercises, reusing shared records")
    func programmeContent() throws {
        let library = try #require(makeModel().library)
        let day1 = try #require(library.routine(id: "day-1"))
        #expect(day1.day == 1)
        #expect(day1.title == "Neck and Shoulder-Blade Foundations")
        #expect(library.exercises(in: day1).map(\.name) == [
            "Supine Chin Tucks", "Scapular Retractions", "Thoracic Extension Over a Chair", "Doorway Chest Stretch",
        ])
        let day10 = try #require(library.routine(id: "day-10"))
        #expect(library.exercises(in: day10).count == 8)
        // Every referenced exercise exists, and each exercise exists once.
        for day in library.programme {
            #expect(library.exercises(in: day).count == day.exerciseIDs.count)
        }
        #expect(Set(library.exercises.map(\.id)).count == library.exercises.count)
    }

    @Test("every exercise is timed and has a category and a short instruction")
    func exerciseMetadata() throws {
        let library = try #require(makeModel().library)
        for exercise in library.exercises {
            #expect(exercise.durationSeconds > 0)
            #expect(!exercise.instruction.isEmpty, "\(exercise.id) has no instruction")
        }
        #expect(library.exercises(in: .desk).count == 7)
        // Durations differ between movements rather than one value for all.
        #expect(Set(library.exercises.map(\.durationSeconds)).count > 1)
    }

    @Test("shows an error state when content can't be loaded")
    func libraryFailure() {
        let model = makeModel(library: FailingLibraryService())
        guard case .failed = model.loadState else {
            Issue.record("Expected failed state, got \(model.loadState)")
            return
        }
        #expect(model.todaysRoutine == nil)
    }

    @Test("completing onboarding persists preferences")
    func onboarding() {
        let model = makeModel()
        var draft = UserPreferences()
        draft.focusAreas = [.hips]
        model.completeOnboarding(with: draft)

        #expect(model.preferences.hasCompletedOnboarding)
        #expect(preferences.stored.hasCompletedOnboarding)
        #expect(preferences.stored.focusAreas == [.hips])
    }

    @Test("a finished session is saved to history and confirmed on Today")
    func finishedSessionSaved() throws {
        let model = makeModel()
        let plan = Fixtures.threeExercisePlan
        model.start(plan)
        let session = try #require(model.activeSession)
        session.startNow()
        clock.advance(30)
        session.tick()
        session.end()

        model.sessionDismissed(session)

        #expect(model.activeSession == nil)
        #expect(model.history.count == 1)
        #expect(model.lastFinishedSession?.exercisesCompleted == 1)
        #expect(snapshots.snapshot == nil)
        #expect(model.progress.totalSessions == 1)
    }

    @Test("a save failure is reported rather than silently lost")
    func saveFailure() throws {
        history.failNextAdd = true
        let model = makeModel()
        model.start(Fixtures.threeExercisePlan)
        let session = try #require(model.activeSession)
        session.startNow()
        clock.advance(30)
        session.end()
        model.sessionDismissed(session)

        #expect(model.historyError != nil)
        #expect(model.history.isEmpty)
    }

    @Test("an interrupted session is offered for resuming after relaunch")
    func resumeAfterRelaunch() throws {
        let first = makeModel()
        first.start(Fixtures.threeExercisePlan)
        let session = try #require(first.activeSession)
        session.startNow()
        clock.advance(10)
        session.pause()
        first.saveProgress(of: session)

        let relaunched = makeModel()
        let snapshot = try #require(relaunched.resumableSnapshot)
        #expect(snapshot.index == 0)

        relaunched.resumeInterruptedSession()
        let resumed = try #require(relaunched.activeSession)
        #expect(resumed.isPaused)
        #expect(resumed.remainingSeconds == 20)
        #expect(relaunched.resumableSnapshot == nil)
    }

    @Test("old interrupted sessions are discarded on launch")
    func staleSnapshotDiscarded() throws {
        let first = makeModel()
        first.start(Fixtures.threeExercisePlan)
        let session = try #require(first.activeSession)
        first.saveProgress(of: session)

        clock.advance(SessionSnapshot.maximumAge + 1)
        let relaunched = makeModel()

        #expect(relaunched.resumableSnapshot == nil)
        #expect(snapshots.snapshot == nil)
    }

    @Test("starting a new session discards any interrupted one")
    func startDiscardsSnapshot() throws {
        let model = makeModel()
        model.start(Fixtures.threeExercisePlan)
        let session = try #require(model.activeSession)
        model.saveProgress(of: session)
        model.activeSession = nil   // the player closes
        model.start(Fixtures.threeExercisePlan)
        #expect(snapshots.snapshot == nil)
    }

    @Test("a second start while a session is opening is ignored")
    func doubleStartIgnored() throws {
        let model = makeModel()
        model.start(Fixtures.threeExercisePlan)
        let first = try #require(model.activeSession)
        model.start(Fixtures.threeExercisePlan)
        #expect(model.activeSession === first)
        let day = try #require(model.library?.routine(id: "day-1"))
        model.startRoutine(day)
        #expect(model.activeSession === first)
    }

    @Test("replaying onboarding shows it again and keeps progress")
    func replayOnboarding() {
        history.sessions = [CompletedSession(
            id: UUID(), routineID: "day-1", title: "Day 1", startedAt: .now, endedAt: .now,
            activeSeconds: 300, exercisesCompleted: 4, exercisesTotal: 4, reachedEnd: true
        )]
        let model = makeModel()
        model.completeOnboarding(with: model.preferences)

        model.replayOnboarding()
        #expect(model.preferences.hasCompletedOnboarding == false)
        #expect(preferences.stored.hasCompletedOnboarding == false, "The choice is persisted")
        #expect(model.history.count == 1)
        #expect(model.programme.completedCount == 1)
    }

    @Test("an empty plan does not open the player")
    func emptyPlanIgnored() {
        let model = makeModel()
        model.start(Fixtures.plan([]))
        #expect(model.activeSession == nil)
    }

    @Test("reset removes history")
    func resetProgress() throws {
        history.sessions = [CompletedSession(
            id: UUID(), routineID: nil, title: "T",
            startedAt: clock.now, endedAt: clock.now,
            activeSeconds: 60, exercisesCompleted: 1, exercisesTotal: 1
        )]
        let model = makeModel()
        #expect(model.history.count == 1)
        model.resetProgress()
        #expect(model.history.isEmpty)
    }
}
