import Foundation
import Testing
@testable import Imposture

@MainActor
struct SessionRecommendationTests {
    private var library: ExerciseLibrary {
        get throws { try BundledExerciseLibraryService().loadLibrary() }
    }

    private func plan(_ library: ExerciseLibrary) -> (Routine) -> SessionPlan? {
        { routine in SessionPlan(routine: routine, library: library) }
    }

    @Test("today's programme day leads, then each guided session once")
    func order() throws {
        let library = try library
        let progress = ProgrammeProgress(programme: library.programme, history: [], now: .now)
        let cards = SessionRecommendations.make(programme: progress, routines: library.routines, plan: plan(library))

        #expect(cards.first?.id == "day-1")
        #expect(cards.first?.label == "Day 1 · Your 10-Day Reset")
        #expect(cards.first?.isProgrammeDay == true)
        #expect(cards.dropFirst().map(\.id) == library.routines.map(\.id))
        #expect(Set(cards.map(\.id)).count == cards.count, "No session appears twice")
    }

    @Test("the programme day describes its real exercises")
    func describesExercises() throws {
        let library = try library
        let progress = ProgrammeProgress(programme: library.programme, history: [], now: .now)
        let card = try #require(SessionRecommendations.make(programme: progress, routines: [], plan: plan(library)).first)
        #expect(card.description == "Supine Chin Tucks, Scapular Retractions and 2 more.")
    }

    @Test("a finished programme leaves only the guided sessions")
    func finishedProgramme() throws {
        let library = try library
        let history = library.programme.map { day in
            CompletedSession(
                id: UUID(), routineID: day.id, title: day.title, startedAt: .now, endedAt: .now,
                activeSeconds: 300, exercisesCompleted: 4, exercisesTotal: 4, reachedEnd: true
            )
        }
        let progress = ProgrammeProgress(programme: library.programme, history: history, now: .now)
        let cards = SessionRecommendations.make(programme: progress, routines: library.routines, plan: plan(library))
        #expect(cards.allSatisfy { !$0.isProgrammeDay })
    }

    @Test("labels come from length and the main kind of exercise")
    func labels() throws {
        let library = try library
        let quick = try #require(library.routine(id: "desk-reset"))
        let quickPlan = SessionPlan(routine: quick, library: library)
        if quickPlan.roundedMinutes <= 5 {
            #expect(SessionRecommendations.label(for: quickPlan) == "Quick reset")
        }
        #expect(SessionRecommendations.exerciseList([]) == "")
    }
}

@MainActor
struct PostureScoreTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    private func check(on day: Date, share: Double?, frames: Int) -> PostureAssessment {
        PostureAssessment(
            id: UUID(), startedAt: day.addingTimeInterval(-600), endedAt: day, activeSeconds: 600,
            framesAnalysed: frames, headFrames: frames, trunkFrames: 0,
            headForwardMedian: share == nil ? nil : 20, headForwardShare: share,
            trunkLeanMedian: nil, trunkLeanShare: nil
        )
    }

    @Test("posture range weights each check by its usable frames")
    func weightedRange() {
        let checks = [check(on: date(27), share: 0.5, frames: 100), check(on: date(27, hour: 15), share: 0.2, frames: 300)]
        let summary = PostureDaySummary(day: date(27), assessments: checks, history: [], calendar: calendar)
        // (0.5 × 100 + 0.8 × 300) / 400
        #expect(abs((summary.postureRange ?? 0) - 0.725) < 0.0001)
        #expect(summary.checks.count == 2)
    }

    @Test("no score, no long sits, and no range without a measured check, never zero")
    func neverInvented() {
        let summary = PostureDaySummary(
            day: date(27),
            assessments: [check(on: date(26), share: 0.1, frames: 100), check(on: date(27), share: nil, frames: 100)],
            history: [], calendar: calendar
        )
        #expect(summary.postureRange == nil)
        #expect(summary.score == nil)
        #expect(summary.longSits == nil)
        #expect(summary.completedSessions == 0)
    }

    @Test("movement is unknown, not zero, when history failed to load")
    func unknownMovement() {
        let viewModel = PostureScoreViewModel(day: date(27), now: { self.date(27) }, calendar: calendar)
        let summary = viewModel.summary(assessments: [], history: [], historyError: "Failed")
        #expect(summary.completedSessions == nil)
    }

    @Test("days step back freely but never past today")
    func dateNavigation() {
        let viewModel = PostureScoreViewModel(day: date(27), now: { self.date(27, hour: 18) }, calendar: calendar)
        #expect(!viewModel.canGoForward)
        #expect(viewModel.heading.hasPrefix("Today"))
        viewModel.goForward()
        #expect(viewModel.day == calendar.startOfDay(for: date(27)))

        viewModel.goBack()
        #expect(viewModel.heading.hasPrefix("Yesterday"))
        #expect(viewModel.canGoForward)
        viewModel.goBack()
        #expect(!viewModel.heading.hasPrefix("Yesterday"))
        viewModel.goForward()
        viewModel.goForward()
        #expect(!viewModel.canGoForward)
    }

    @Test("a future day is pulled back to today")
    func clampsFuture() {
        let viewModel = PostureScoreViewModel(day: date(30), now: { self.date(27) }, calendar: calendar)
        #expect(viewModel.day == calendar.startOfDay(for: date(27)))
    }

    @Test("long exercise time reads in hours")
    func hours() {
        let viewModel = ProgressViewModel(cameraAccess: { .authorized })
        let session = CompletedSession(
            id: UUID(), routineID: nil, title: "Long", startedAt: .now.addingTimeInterval(-5000), endedAt: .now,
            activeSeconds: 80 * 60, exercisesCompleted: 3, exercisesTotal: 3
        )
        let dashboard = viewModel.dashboard(history: [session], assessments: [])
        let reading = viewModel.exerciseTime(dashboard, history: [session], error: nil)
        #expect(reading.value == "1")
        #expect(reading.unit == "h 20 min")
    }
}

struct PreparationStepTests {
    @Test("five steps in order, with progress that only moves forward")
    func steps() {
        #expect(PostureCheckStep.allCases.count == 5)
        #expect(PostureCheckStep.phone.next == nil)
        var previous = 0
        for step in PostureCheckStep.allCases {
            #expect(step.progress >= previous)
            #expect(step.previousProgress <= step.progress)
            previous = step.progress
        }
        #expect(PostureCheckStep.phone.progress == 4)
    }
}
