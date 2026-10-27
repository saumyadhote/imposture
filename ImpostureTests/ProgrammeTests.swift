import Foundation
import Testing
@testable import Imposture

@MainActor
struct ProgrammeTests {
    let clock = TestClock()
    let history = InMemoryHistoryStore()
    let preferences = InMemoryPreferencesStore()

    private func makeModel() -> AppModel {
        let model = AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: preferences,
            historyStore: history,
            snapshotStore: InMemorySnapshotStore(),
            assessmentStore: InMemoryAssessmentStore(),
            reminders: MockReminders(),
            clock: clock.function
        )
        model.load()
        return model
    }

    private func session(_ routineID: String, endedAt: Date, reachedEnd: Bool = true, completed: Int = 4) -> CompletedSession {
        CompletedSession(
            id: UUID(), routineID: routineID, title: routineID,
            startedAt: endedAt.addingTimeInterval(-300), endedAt: endedAt,
            activeSeconds: 280, exercisesCompleted: completed, exercisesTotal: 5, reachedEnd: reachedEnd
        )
    }

    @Test("day 1 is recommended first and nothing is locked")
    func freshProgramme() {
        let progress = makeModel().programme
        #expect(progress.current?.id == "day-1")
        #expect(progress.days.count == 10)
        #expect(progress.status(of: progress.days[4]) == .upcoming)
        #expect(progress.completedCount == 0)
    }

    @Test("a session that ran to the end completes its day, even with skips")
    func completionWithSkips() {
        history.sessions = [session("day-1", endedAt: clock.now, reachedEnd: true, completed: 3)]
        let progress = makeModel().programme
        #expect(progress.status(of: progress.days[0]) == .completed)
        #expect(progress.current?.id == "day-2")
        #expect(progress.hasCompletedToday)
    }

    @Test("a session ended early doesn't complete its day")
    func endedEarly() {
        history.sessions = [session("day-1", endedAt: clock.now, reachedEnd: false, completed: 2)]
        #expect(makeModel().programme.current?.id == "day-1")
    }

    @Test("the programme is complete after all ten days")
    func programmeComplete() {
        history.sessions = (1...10).map { session("day-\($0)", endedAt: clock.now.addingTimeInterval(Double(-$0) * 86_400)) }
        let progress = makeModel().programme
        #expect(progress.isComplete)
        #expect(progress.current == nil)
    }

    // MARK: - Recovery suggestion

    @Test("starting the next day right after finishing one offers recovery instead")
    func offersRecovery() throws {
        history.sessions = [session("day-1", endedAt: clock.now)]
        let model = makeModel()
        let day2 = try #require(model.library?.routine(id: "day-2"))
        model.startRoutine(day2)

        let offer = try #require(model.recoveryOffer)
        #expect(model.activeSession == nil)
        #expect(offer.requested.id == "day-2")
        #expect(offer.alternatives.map(\.id) == ["gentle-mobility", "desk-reset"])
    }

    @Test("continuing to the next day starts it once the sheet is dismissed")
    func continueAfterRecovery() throws {
        history.sessions = [session("day-1", endedAt: clock.now)]
        let model = makeModel()
        let day2 = try #require(model.library?.routine(id: "day-2"))
        model.startRoutine(day2)
        model.chooseFromRecoveryOffer(day2)
        #expect(model.activeSession == nil)
        model.recoverySheetDismissed()
        #expect(model.activeSession?.plan.routineID == "day-2")
    }

    @Test("choosing recovery starts Gentle Mobility")
    func startRecovery() throws {
        history.sessions = [session("day-1", endedAt: clock.now)]
        let model = makeModel()
        let day2 = try #require(model.library?.routine(id: "day-2"))
        model.startRoutine(day2)
        let gentle = try #require(model.recoveryOffer?.alternatives.first)
        model.chooseFromRecoveryOffer(gentle)
        model.recoverySheetDismissed()
        #expect(model.activeSession?.plan.routineID == "gentle-mobility")
    }

    @Test("swiping the sheet away starts nothing")
    func dismissStartsNothing() throws {
        history.sessions = [session("day-1", endedAt: clock.now)]
        let model = makeModel()
        model.startRoutine(try #require(model.library?.routine(id: "day-2")))
        model.recoverySheetDismissed()
        #expect(model.activeSession == nil)
        #expect(model.recoveryOffer == nil)
    }

    @Test("the suggestion appears at most once a day")
    func onlyOncePerDay() throws {
        history.sessions = [session("day-1", endedAt: clock.now)]
        let model = makeModel()
        let day2 = try #require(model.library?.routine(id: "day-2"))
        model.startRoutine(day2)
        model.recoverySheetDismissed()
        model.startRoutine(day2)
        #expect(model.recoveryOffer == nil)
        #expect(model.activeSession?.plan.routineID == "day-2")
    }

    @Test("no suggestion when repeating today's day, starting a routine, or on a new day")
    func noSuggestion() throws {
        history.sessions = [session("day-1", endedAt: clock.now.addingTimeInterval(-86_400 * 2))]
        let model = makeModel()
        let library = try #require(model.library)
        model.startRoutine(try #require(library.routine(id: "day-2")))
        #expect(model.recoveryOffer == nil)

        history.sessions = [session("day-1", endedAt: clock.now)]
        model.reloadHistory()
        #expect(!model.shouldOfferRecovery(before: try #require(library.routine(id: "day-1"))))
        #expect(!model.shouldOfferRecovery(before: try #require(library.routine(id: "desk-reset"))))
    }

    @Test("both recovery routines get real durations from their exercises")
    func recoveryDurations() throws {
        let model = makeModel()
        for id in [Routine.gentleMobilityID, Routine.deskResetID] {
            let plan = try #require(model.library?.routine(id: id).flatMap(model.plan(for:)))
            #expect(plan.totalDuration > 0)
            #expect(plan.exercises.count == 4)
        }
    }
}
