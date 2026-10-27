import Foundation
import Testing
@testable import Imposture

struct ProgressDashboardTests {
    /// Gregorian, Monday-first, UTC, so weeks and months are predictable.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func session(on day: Date, exercises: Int, minutes: Double = 5) -> CompletedSession {
        CompletedSession(
            id: UUID(), routineID: nil, title: "Session",
            startedAt: day.addingTimeInterval(-minutes * 60), endedAt: day,
            activeSeconds: minutes * 60, exercisesCompleted: exercises, exercisesTotal: exercises
        )
    }

    // Wednesday 14 October 2026. Its week runs Mon 12 – Sun 18.
    private var now: Date { date(2026, 10, 14, hour: 18) }

    private func assessment(on day: Date, head: Double? = 20, share: Double? = 0.4) -> PostureAssessment {
        PostureAssessment(
            id: UUID(), startedAt: day.addingTimeInterval(-600), endedAt: day, activeSeconds: 600,
            framesAnalysed: 600, headFrames: 500, trunkFrames: 0,
            headForwardMedian: head, headForwardShare: share, trunkLeanMedian: nil, trunkLeanShare: nil
        )
    }

    private func ended(on day: Date, done: Int, of total: Int, minutes: Double = 5) -> CompletedSession {
        CompletedSession(
            id: UUID(), routineID: nil, title: "Session",
            startedAt: day.addingTimeInterval(-minutes * 60), endedAt: day,
            activeSeconds: minutes * 60, exercisesCompleted: done, exercisesTotal: total
        )
    }

    @Test("periods: today, Monday-to-Sunday week, and a rolling 30 days")
    func periods() {
        let today = ProgressPeriod.today.interval(containing: now, calendar: calendar)
        #expect(today.start == date(2026, 10, 14, hour: 0))
        #expect(today.end == date(2026, 10, 15, hour: 0))

        // Even with a Sunday-first calendar, the week starts on Monday.
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        let week = ProgressPeriod.thisWeek.interval(containing: now, calendar: sundayFirst)
        #expect(week.start == date(2026, 10, 12, hour: 0))
        #expect(week.end == date(2026, 10, 19, hour: 0))

        let month = ProgressPeriod.last30Days.interval(containing: now, calendar: calendar)
        #expect(month.start == date(2026, 9, 15, hour: 0))
        #expect(month.end == date(2026, 10, 15, hour: 0))
    }

    @Test("weekly totals count only this week's sessions")
    func weeklyTotals() {
        let history = [
            session(on: date(2026, 10, 12), exercises: 7, minutes: 7),
            session(on: date(2026, 10, 12, hour: 15), exercises: 4, minutes: 3),
            session(on: date(2026, 10, 14), exercises: 3, minutes: 2),
            session(on: date(2026, 10, 9), exercises: 9),   // last week
        ]
        let dashboard = ProgressDashboard(history: history, assessments: [], period: .thisWeek, now: now, calendar: calendar)

        #expect(dashboard.completedSessions == 3)
        #expect(dashboard.activeDays == 2, "Two sessions on the same day count once")
        #expect(dashboard.minutes == 12)
        #expect(dashboard.days.count == 7)
        #expect(dashboard.chart.map(\.minutes) == [10, 0, 2, 0, 0, 0, 0])
        #expect(dashboard.chart.filter(\.isFuture).count == 4, "Days still to come are gaps, not zeros")
    }

    @Test("only finished routines count as sessions, but all active time counts")
    func completedOnly() {
        let history = [
            ended(on: date(2026, 10, 13), done: 2, of: 7, minutes: 3),   // ended early
            ended(on: date(2026, 10, 14), done: 7, of: 7, minutes: 7),
        ]
        let dashboard = ProgressDashboard(history: history, assessments: [], period: .thisWeek, now: now, calendar: calendar)
        #expect(dashboard.completedSessions == 1)
        #expect(dashboard.minutes == 10)
        #expect(dashboard.activeDays == 1)
        #expect(dashboard.trackingDays == 2)
        #expect(dashboard.consistency == 0.5)
    }

    @Test("tracking days include measured posture checks, but not ones that measured nothing")
    func trackingDays() {
        let assessments = [
            assessment(on: date(2026, 10, 12)),
            assessment(on: date(2026, 10, 13), head: nil, share: nil),
        ]
        let history = [session(on: date(2026, 10, 14), exercises: 3)]
        let dashboard = ProgressDashboard(history: history, assessments: assessments, period: .thisWeek, now: now, calendar: calendar)
        #expect(dashboard.trackingDays == 2)
        #expect(dashboard.days.map(\.isTracked) == [true, false, true, false, false, false, false])
        #expect(dashboard.latestAssessment?.endedAt == date(2026, 10, 12))
    }

    @Test("today charts by the hour")
    func todayChart() {
        let history = [session(on: date(2026, 10, 14, hour: 9), exercises: 3, minutes: 4)]
        let dashboard = ProgressDashboard(history: history, assessments: [], period: .today, now: now, calendar: calendar)
        #expect(dashboard.chart.count == 24)
        #expect(dashboard.chart[9].minutes == 4)
        #expect(dashboard.chart.filter(\.isFuture).count == 5, "Hours after 18:00 haven't happened yet")
        #expect(dashboard.days.count == 1)
    }

    @Test("with nothing tracked, consistency is absent rather than 0%")
    func noConsistency() {
        let dashboard = ProgressDashboard(history: [], assessments: [], period: .thisWeek, now: now, calendar: calendar)
        #expect(dashboard.consistency == nil)
        #expect(dashboard.latestAssessment == nil)
    }

    @Test("all sessions are listed newest first, whatever the period")
    func allSessions() {
        let older = session(on: date(2026, 8, 1), exercises: 3)
        let newer = session(on: date(2026, 10, 13), exercises: 3)
        let dashboard = ProgressDashboard(history: [older, newer], assessments: [], period: .thisWeek, now: now, calendar: calendar)
        #expect(dashboard.allSessions.map(\.id) == [newer.id, older.id])
    }

    @Test("streak counts consecutive days ending today, and survives until a full day is missed")
    func streaks() {
        let days = [14, 13, 12, 9, 8, 7, 6].map { date(2026, 10, $0) }
        let history = days.map { session(on: $0, exercises: 3) }
        let dashboard = ProgressDashboard(history: history, assessments: [], period: .thisWeek, now: now, calendar: calendar)
        #expect(dashboard.currentStreak == 3)
        #expect(dashboard.longestStreak == 4)

        // No session yet today: yesterday's run still counts.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let next = ProgressDashboard(history: history, assessments: [], period: .thisWeek, now: tomorrow, calendar: calendar)
        #expect(next.currentStreak == 3)
    }

    @Test("sample data gives a four-day streak")
    func sampleStreak() {
        #expect(ProgressDashboard.sample(period: .thisWeek, now: now, calendar: calendar).currentStreak == 4)
    }

    @Test("sample data fills every period and never lies in the future")
    func sample() {
        for period in ProgressPeriod.allCases {
            let dashboard = ProgressDashboard.sample(period: period, now: now, calendar: calendar)
            #expect(dashboard.completedSessions > 0)
            #expect(dashboard.trackingDays > 0)
            #expect(dashboard.latestAssessment != nil)
            #expect(dashboard.allSessions.allSatisfy { $0.endedAt <= now })
        }
    }
}

@MainActor
struct ProgressViewModelTests {
    private func assessment(daysAgo: Double, head: Double) -> PostureAssessment {
        let end = Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(-daysAgo * 86_400)
        return PostureAssessment(
            id: UUID(), startedAt: end.addingTimeInterval(-600), endedAt: end, activeSeconds: 600,
            framesAnalysed: 600, headFrames: 500, trunkFrames: 500,
            headForwardMedian: head, headForwardShare: 0.4, trunkLeanMedian: 8, trunkLeanShare: 0.1
        )
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func viewModel(camera: CameraAccess = .authorized) -> ProgressViewModel {
        let viewModel = ProgressViewModel(now: { now }, cameraAccess: { camera })
        viewModel.refreshCameraAccess()
        return viewModel
    }

    @Test("with sample data off, the dashboard uses real history and assessments")
    func realData() {
        let viewModel = viewModel()
        #expect(viewModel.dashboard(history: [], assessments: []).latestAssessment == nil)
        let dashboard = viewModel.dashboard(history: [], assessments: [assessment(daysAgo: 0, head: 20)])
        #expect(dashboard.completedSessions == 0)
        #expect(dashboard.latestAssessment != nil)
    }

    @Test("changing the period changes the dashboard")
    func period() {
        let viewModel = viewModel()
        let old = [assessment(daysAgo: 10, head: 20)]
        #expect(viewModel.dashboard(history: [], assessments: old).latestAssessment == nil)
        viewModel.period = .last30Days
        #expect(viewModel.dashboard(history: [], assessments: old).latestAssessment != nil)
    }

    @Test("metrics read — when history failed to load, never 0")
    func unknownWhenHistoryFails() {
        let viewModel = viewModel()
        let dashboard = viewModel.dashboard(history: [], assessments: [])
        let error = "Your progress couldn't be loaded."
        #expect(viewModel.sessions(dashboard, history: [], error: error).value == "—")
        #expect(viewModel.exerciseTime(dashboard, history: [], error: error).value == "—")
        #expect(viewModel.consistency(dashboard, history: [], error: error).isKnown == false)
        #expect(viewModel.trackingDays(dashboard, history: [], historyError: error, assessments: [], assessmentsError: nil).value == "—")
    }

    @Test("a confirmed empty period reads 0, but consistency stays — without tracked days")
    func confirmedZero() {
        let viewModel = viewModel()
        let dashboard = viewModel.dashboard(history: [], assessments: [])
        #expect(viewModel.exerciseTime(dashboard, history: [], error: nil).value == "0")
        #expect(viewModel.trackingDays(dashboard, history: [], historyError: nil, assessments: [], assessmentsError: nil).value == "0")
        #expect(viewModel.consistency(dashboard, history: [], error: nil).value == "—")
    }

    @Test("the posture card shows measurements, never a made-up score")
    func postureStates() {
        let measured = viewModel()
        let assessments = [assessment(daysAgo: 0, head: 20)]
        let dashboard = measured.dashboard(history: [], assessments: assessments)
        guard case .measured(_, let inRange, _) = measured.posture(dashboard, assessments: assessments, error: nil) else {
            Issue.record("Expected a measured state")
            return
        }
        #expect(abs(inRange - 0.6) < 0.0001)

        let empty = measured.dashboard(history: [], assessments: [])
        #expect(measured.posture(empty, assessments: [], error: nil) == .notEnoughData)
        #expect(viewModel(camera: .denied).posture(empty, assessments: [], error: nil) == .cameraDenied)
        #expect(measured.posture(empty, assessments: [], error: "Failed") == .unavailable("Failed"))
    }

    @Test("no data only when nothing is recorded and nothing failed")
    func noData() {
        let viewModel = viewModel()
        #expect(viewModel.hasNoData(history: [], assessments: [], errors: [nil, nil]))
        #expect(!viewModel.hasNoData(history: [], assessments: [], errors: ["Failed", nil]))
        #expect(!viewModel.hasNoData(history: [], assessments: [assessment(daysAgo: 0, head: 20)], errors: [nil, nil]))
    }

    @Test("a report is compared with the assessment just before it")
    func comparesWithPrevious() {
        let viewModel = ProgressViewModel()
        let all = [assessment(daysAgo: 0, head: 15), assessment(daysAgo: 1, head: 25), assessment(daysAgo: 5, head: 15)]
        let latest = viewModel.analysis(for: all[0], in: all)
        #expect(latest.findings.first?.trend == .better("10° less than last time"))
        let oldest = viewModel.analysis(for: all[2], in: all)
        #expect(!oldest.comparedWithPrevious)
    }
}

struct PostureAnalysisTests {
    private func analysis(headFrames: Int, of total: Int) -> PostureAnalysis {
        PostureAnalysis(PostureAssessment(
            id: UUID(), startedAt: .now, endedAt: .now, activeSeconds: 600,
            framesAnalysed: total, headFrames: headFrames, trunkFrames: 0,
            headForwardMedian: nil, headForwardShare: nil, trunkLeanMedian: nil, trunkLeanShare: nil
        ))
    }

    @Test("observation quality follows how much of the assessment was usable")
    func quality() {
        #expect(analysis(headFrames: 520, of: 600).observationQuality == "Good")
        #expect(analysis(headFrames: 360, of: 600).observationQuality == "Fair")
        #expect(analysis(headFrames: 120, of: 600).observationQuality == "Low")
        #expect(analysis(headFrames: 0, of: 0).observationQuality == "Low")
    }

    @Test("unmeasured findings say so instead of inventing values")
    func notAssessed() {
        let report = analysis(headFrames: 0, of: 100)
        #expect(report.findings.allSatisfy { $0.reliability == .notAssessed })
        #expect(report.findings.allSatisfy { $0.trend == nil })
    }
}
