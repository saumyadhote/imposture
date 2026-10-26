import Foundation

enum ProgressPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Weekly"
        case .month: "Monthly"
        }
    }

    fileprivate var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// Everything the Progress screen shows for one week or month.
struct ProgressDashboard: Equatable {
    /// One bar in the activity chart: a day (weekly view) or a week (monthly view).
    struct Bar: Identifiable, Equatable {
        let start: Date
        let label: String
        let exercises: Int
        var id: Date { start }
    }

    let period: ProgressPeriod
    let interval: DateInterval
    let exercisesDone: Int
    let activeDays: Int
    /// Days in the period, for "4 of 7 days".
    let daysInPeriod: Int
    let minutes: Int
    let postureReports: Int
    let latestPostureReport: Date?
    let bars: [Bar]
    /// Every session, newest first. Not limited to the period.
    let allSessions: [CompletedSession]

    /// One day of the current week, for the streak strip.
    struct WeekDay: Identifiable, Equatable {
        let date: Date
        let isActive: Bool
        let isToday: Bool
        let isFuture: Bool
        var id: Date { date }
    }

    /// The seven days of the week containing `now`.
    let weekDays: [WeekDay]
    /// Consecutive active days ending today, or yesterday if today has no session yet.
    let currentStreak: Int
    /// Longest run of consecutive active days in the whole history.
    let longestStreak: Int

    init(
        history: [CompletedSession],
        postureReportDates: [Date],
        period: ProgressPeriod,
        now: Date,
        calendar: Calendar = .current
    ) {
        let interval = calendar.dateInterval(of: period.component, for: now)
            ?? DateInterval(start: calendar.startOfDay(for: now), duration: 86_400)
        let inPeriod = history.filter { interval.contains($0.endedAt) }
        let reports = postureReportDates.filter { interval.contains($0) }

        self.period = period
        self.interval = interval
        exercisesDone = inPeriod.reduce(0) { $0 + $1.exercisesCompleted }
        activeDays = Set(inPeriod.map { calendar.startOfDay(for: $0.endedAt) }).count
        daysInPeriod = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        minutes = Int((inPeriod.reduce(0) { $0 + $1.activeSeconds } / 60).rounded())
        postureReports = reports.count
        latestPostureReport = reports.max()
        bars = Self.makeBars(for: period, in: interval, sessions: inPeriod, calendar: calendar)
        allSessions = history.sorted { $0.endedAt > $1.endedAt }

        let active = Set(history.map { calendar.startOfDay(for: $0.endedAt) })
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        weekDays = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return WeekDay(date: day, isActive: active.contains(day), isToday: day == today, isFuture: day > today)
        }
        currentStreak = Self.streak(endingAt: today, in: active, calendar: calendar)
        longestStreak = Self.longestStreak(in: active, calendar: calendar)
    }

    private static func streak(endingAt today: Date, in active: Set<Date>, calendar: Calendar) -> Int {
        // A streak isn't broken until a whole day passes without a session.
        var day = active.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        var count = 0
        while active.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private static func longestStreak(in active: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0, run = 0
        var previous: Date?
        for day in active.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day { run += 1 } else { run = 1 }
            longest = max(longest, run)
            previous = day
        }
        return longest
    }

    private static func makeBars(
        for period: ProgressPeriod,
        in interval: DateInterval,
        sessions: [CompletedSession],
        calendar: Calendar
    ) -> [Bar] {
        // Days for a week; weeks (clipped to the month) for a month.
        let step: Calendar.Component = period == .week ? .day : .weekOfYear
        var bars: [Bar] = []
        var cursor = interval.start
        while cursor < interval.end {
            let bucketEnd = min(
                calendar.dateInterval(of: step, for: cursor)?.end ?? interval.end,
                interval.end
            )
            let exercises = sessions
                .filter { $0.endedAt >= cursor && $0.endedAt < bucketEnd }
                .reduce(0) { $0 + $1.exercisesCompleted }
            let label = period == .week
                ? cursor.formatted(.dateTime.weekday(.narrow))
                : "Wk \(bars.count + 1)"
            bars.append(Bar(start: cursor, label: label, exercises: exercises))
            cursor = bucketEnd
        }
        return bars
    }
}

// MARK: - Sample data

extension ProgressDashboard {
    /// Placeholder content so the screen can be designed before there's real history.
    static func sample(period: ProgressPeriod, now: Date, calendar: Calendar = .current) -> ProgressDashboard {
        ProgressDashboard(
            history: sampleHistory(now: now, calendar: calendar),
            postureReportDates: [0, 9, 16].compactMap { calendar.date(byAdding: .day, value: -$0, to: now) },
            period: period,
            now: now,
            calendar: calendar
        )
    }

    /// About three sessions a week for the past five weeks.
    private static func sampleHistory(now: Date, calendar: Calendar) -> [CompletedSession] {
        let pattern: [(daysAgo: Int, title: String, done: Int, total: Int, minutes: Double)] = [
            (0, "Week 1", 7, 7, 7), (1, "Desk Reset", 4, 4, 3), (2, "Week 1", 6, 7, 6), (3, "Week 1", 7, 7, 7),
            (5, "Week 1", 5, 7, 5), (7, "Stand-Up Break", 4, 4, 4), (8, "Week 1", 7, 7, 7),
            (10, "Desk Reset", 4, 4, 3), (13, "Week 1", 7, 7, 7), (15, "Steady Legs", 3, 3, 3),
            (17, "Week 1", 6, 7, 6), (20, "Desk Reset", 4, 4, 3), (22, "Week 1", 7, 7, 7),
            (26, "Posture Refresh", 6, 6, 5), (29, "Week 1", 7, 7, 7), (33, "Desk Reset", 4, 4, 3),
        ]
        return pattern.enumerated().compactMap { index, entry in
            guard let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now) else { return nil }
            // Keep each session at or before `now`, so today's sample is never in the future.
            let end = min(calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day) ?? day, now)
            return CompletedSession(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID(),
                routineID: nil,
                title: entry.title,
                startedAt: end.addingTimeInterval(-entry.minutes * 60),
                endedAt: end,
                activeSeconds: entry.minutes * 60,
                exercisesCompleted: entry.done,
                exercisesTotal: entry.total
            )
        }
    }
}
