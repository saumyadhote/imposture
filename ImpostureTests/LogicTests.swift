import Foundation
import Testing
@testable import Imposture

@MainActor
struct LibraryViewModelTests {
    @Test("search matches names, body areas and positions, ignoring case")
    func search() throws {
        let library = try Fixtures.bundledLibrary()
        let viewModel = LibraryViewModel()

        viewModel.searchText = "NECK"
        #expect(viewModel.results(in: library).map(\.id).contains("chin-tuck"))

        viewModel.searchText = "standing hips"
        #expect(viewModel.results(in: library).map(\.id) == ["standing-hip-flexor-stretch"])
    }

    @Test("position filter narrows results and can be cleared")
    func positionFilter() throws {
        let library = try Fixtures.bundledLibrary()
        let viewModel = LibraryViewModel()
        viewModel.position = .floor

        #expect(viewModel.isFiltering)
        let floor = viewModel.results(in: library)
        #expect(floor.contains { $0.id == "cat-cow" })
        #expect(floor.allSatisfy { $0.position == .floor })

        viewModel.clearFilters()
        #expect(!viewModel.isFiltering)
        #expect(viewModel.results(in: library).count == library.exercises.count)
    }

    @Test("a search with no matches returns an empty list")
    func noMatches() throws {
        let library = try Fixtures.bundledLibrary()
        let viewModel = LibraryViewModel()
        viewModel.searchText = "trampoline"
        #expect(viewModel.results(in: library).isEmpty)
    }
}

struct LibraryContentTests {
    @Test("every routine refers to real exercises and every illustration exists")
    func contentIsConsistent() throws {
        let library = try Fixtures.bundledLibrary()
        for routine in library.routines {
            #expect(library.exercises(in: routine).count == routine.exerciseIDs.count, "\(routine.id)")
        }
        for exercise in library.exercises {
            #expect(!exercise.steps.isEmpty, "\(exercise.id)")
            #expect(!exercise.cautions.isEmpty, "\(exercise.id)")
            #expect(!exercise.illustrationDescription.isEmpty, "\(exercise.id)")
        }
    }
}

struct RoutineRecommenderTests {
    @Test("seated-only preference only suggests fully seated routines")
    func seatedOnly() throws {
        let library = try Fixtures.bundledLibrary()
        var preferences = UserPreferences()
        preferences.positionPreference = .seatedOnly

        let ranked = RoutineRecommender(library: library).rankedRoutines(for: preferences)
        #expect(!ranked.isEmpty)
        for routine in ranked {
            #expect(SessionPlan(routine: routine, library: library).positions == [.seated])
        }
    }

    @Test("long sessions rank the longest routine first")
    func longPreference() throws {
        let library = try Fixtures.bundledLibrary()
        var preferences = UserPreferences()
        preferences.sessionLength = .long

        let ranked = RoutineRecommender(library: library).rankedRoutines(for: preferences)
        #expect(ranked.first?.id == "full-break")
    }

    @Test("the suggestion is stable within a day and alternates between days")
    func dailyRotation() throws {
        let library = try Fixtures.bundledLibrary()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let recommender = RoutineRecommender(library: library, calendar: calendar)
        let preferences = UserPreferences()
        let morning = Date(timeIntervalSince1970: 1_800_000_000)

        let first = recommender.recommendation(for: preferences, on: morning)
        let sameDay = recommender.recommendation(for: preferences, on: morning.addingTimeInterval(3600))
        let nextDay = recommender.recommendation(for: preferences, on: morning.addingTimeInterval(86_400))

        #expect(first == sameDay)
        #expect(first != nextDay)
    }
}

struct ProgressSummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    private func session(endedAt: Date, seconds: TimeInterval) -> CompletedSession {
        CompletedSession(
            id: UUID(), routineID: nil, title: "S",
            startedAt: endedAt.addingTimeInterval(-seconds), endedAt: endedAt,
            activeSeconds: seconds, exercisesCompleted: 1, exercisesTotal: 1
        )
    }

    @Test("empty history gives an empty summary with a full week")
    func empty() {
        let summary = ProgressSummary(history: [], now: .now, calendar: calendar)
        #expect(summary.isEmpty)
        #expect(summary.week.count == 7)
        #expect(summary.week.filter(\.isToday).count == 1)
    }

    @Test("counts distinct active days and minutes this week")
    func weekTotals() throws {
        // Wednesday 15 January 2025, 12:00 GMT.
        let now = try #require(calendar.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12)))
        let history = [
            session(endedAt: now, seconds: 120),
            session(endedAt: now.addingTimeInterval(-3600), seconds: 60),
            session(endedAt: now.addingTimeInterval(-86_400), seconds: 180),
            // Previous week: counts toward totals only.
            session(endedAt: now.addingTimeInterval(-7 * 86_400), seconds: 600),
        ]
        let summary = ProgressSummary(history: history, now: now, calendar: calendar)

        #expect(summary.activeDaysThisWeek == 2)
        #expect(summary.minutesThisWeek == 6)
        #expect(summary.totalSessions == 4)
        #expect(summary.totalMinutes == 16)
    }
}

struct DurationTextTests {
    @Test("formats short durations readably", arguments: [
        (45.0, "45 sec"), (60.0, "1 min"), (90.0, "1 min 30 sec"), (300.0, "5 min"),
    ])
    func short(seconds: Double, expected: String) {
        #expect(DurationText.short(seconds) == expected)
    }

    @Test("formats countdowns as m:ss")
    func clock() {
        #expect(DurationText.clock(5) == "0:05")
        #expect(DurationText.clock(75) == "1:15")
    }
}

@MainActor
struct SettingsViewModelTests {
    private func makeModel(reminders: MockReminders) -> AppModel {
        let model = AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: InMemoryPreferencesStore(),
            historyStore: InMemoryHistoryStore(),
            snapshotStore: InMemorySnapshotStore(),
            reminders: reminders
        )
        model.load()
        return model
    }

    @Test("turning reminders off cancels them")
    func disable() async {
        let reminders = MockReminders()
        let model = makeModel(reminders: reminders)
        let viewModel = SettingsViewModel(appModel: model)

        await viewModel.setRemindersEnabled(true)
        #expect(model.preferences.remindersEnabled)
        await viewModel.setRemindersEnabled(false)
        #expect(!model.preferences.remindersEnabled)
        #expect(reminders.cancelCount == 1)
    }

    @Test("changing the time reschedules an enabled reminder")
    func reschedule() async {
        let reminders = MockReminders()
        let model = makeModel(reminders: reminders)
        let viewModel = SettingsViewModel(appModel: model)
        await viewModel.setRemindersEnabled(true)

        await viewModel.setReminderTime(ReminderTime(hour: 15, minute: 0))

        #expect(reminders.scheduled.last == ReminderTime(hour: 15, minute: 0))
        #expect(model.preferences.reminderTime == ReminderTime(hour: 15, minute: 0))
    }

    @Test("denied permission shows a message and keeps reminders off")
    func denied() async {
        let reminders = MockReminders()
        reminders.allow = false
        let model = makeModel(reminders: reminders)
        let viewModel = SettingsViewModel(appModel: model)

        await viewModel.setRemindersEnabled(true)

        #expect(!model.preferences.remindersEnabled)
        #expect(viewModel.reminderMessage != nil)
    }
}
