import Foundation

/// The span of time the Progress screen summarises.
enum ProgressPeriod: String, CaseIterable, Identifiable, Sendable {
    /// The current calendar day.
    case today
    /// Monday to Sunday of the current week.
    case thisWeek
    /// Today and the 29 days before it.
    case last30Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "This Week"
        case .last30Days: "Last 30 Days"
        }
    }

    /// The period's dates, whole days in `calendar`'s time zone. Weeks always start on Monday.
    func interval(containing now: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        switch self {
        case .today:
            return DateInterval(start: today, end: tomorrow)
        case .thisWeek:
            var monday = calendar
            monday.firstWeekday = 2
            return monday.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: today, end: tomorrow)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return DateInterval(start: start, end: tomorrow)
        }
    }
}

/// Everything the Progress screen shows for one period, derived from saved sessions and
/// posture assessments. Nothing is estimated: a value is either counted or absent.
struct ProgressDashboard: Equatable {
    /// One slot in a period chart: an hour (Today) or a day (This Week, Last 30 Days).
    struct Bucket: Identifiable, Equatable {
        let start: Date
        let completedSessions: Int
        let minutes: Int
        /// A session or a measured posture assessment happened in this slot.
        let isTracked: Bool
        /// Not reached yet. Drawn as a gap, never as zero.
        let isFuture: Bool
        var id: Date { start }
    }

    let period: ProgressPeriod
    let interval: DateInterval
    /// Sessions that ran to the end of their routine.
    let completedSessions: Int
    /// Active minutes across every recorded session, finished or not. Pauses are already excluded.
    let minutes: Int
    /// Days with at least one completed routine.
    let activeDays: Int
    /// Days with any session or a posture assessment that produced measurements.
    let trackingDays: Int
    /// Hours for Today, days otherwise.
    let chart: [Bucket]
    /// The period's days, for the tracking strip.
    let days: [Bucket]
    /// The most recent assessment in the period that measured something.
    let latestAssessment: PostureAssessment?
    /// Every session, newest first. Not limited to the period.
    let allSessions: [CompletedSession]
    /// Consecutive active days ending today, or yesterday if today has no session yet.
    let currentStreak: Int
    /// Longest run of consecutive active days in the whole history.
    let longestStreak: Int

    /// Active days ÷ tracking days. Nil when nothing was tracked, so it can't read as 0%.
    var consistency: Double? {
        trackingDays > 0 ? Double(activeDays) / Double(trackingDays) : nil
    }

    init(
        history: [CompletedSession],
        assessments: [PostureAssessment],
        period: ProgressPeriod,
        now: Date,
        calendar: Calendar = .current
    ) {
        let interval = period.interval(containing: now, calendar: calendar)
        let sessions = history.filter { interval.contains($0.endedAt) }
        let measured = assessments.filter { $0.hasFindings && interval.contains($0.endedAt) }

        let completed = sessions.filter(\.completesRoutine)
        let day = { (date: Date) in calendar.startOfDay(for: date) }
        let activeDaySet = Set(completed.map { day($0.endedAt) })
        let trackedDaySet = Set(sessions.map { day($0.endedAt) } + measured.map { day($0.endedAt) })

        self.period = period
        self.interval = interval
        completedSessions = completed.count
        minutes = Self.activeMinutes(sessions)
        activeDays = activeDaySet.count
        trackingDays = trackedDaySet.count
        latestAssessment = measured.max { $0.endedAt < $1.endedAt }
        allSessions = history.sorted { $0.endedAt > $1.endedAt }

        days = Self.buckets(of: .day, in: interval, sessions: sessions, measured: measured, now: now, calendar: calendar)
        chart = period == .today
            ? Self.buckets(of: .hour, in: interval, sessions: sessions, measured: measured, now: now, calendar: calendar)
            : days

        let everActive = Set(history.map { day($0.endedAt) })
        let today = day(now)
        currentStreak = Self.streak(endingAt: today, in: everActive, calendar: calendar)
        longestStreak = Self.longestStreak(in: everActive, calendar: calendar)
    }

    private static func activeMinutes(_ sessions: [CompletedSession]) -> Int {
        Int((sessions.reduce(0) { $0 + $1.activeSeconds } / 60).rounded())
    }

    private static func buckets(
        of unit: Calendar.Component,
        in interval: DateInterval,
        sessions: [CompletedSession],
        measured: [PostureAssessment],
        now: Date,
        calendar: Calendar
    ) -> [Bucket] {
        var buckets: [Bucket] = []
        var cursor = interval.start
        while cursor < interval.end {
            let next = min(calendar.date(byAdding: unit, value: 1, to: cursor) ?? interval.end, interval.end)
            let slot = DateInterval(start: cursor, end: next)
            // End-exclusive, so a session finishing exactly on the hour lands in one slot.
            let inSlot = sessions.filter { $0.endedAt >= cursor && $0.endedAt < next }
            buckets.append(Bucket(
                start: cursor,
                completedSessions: inSlot.filter(\.completesRoutine).count,
                minutes: activeMinutes(inSlot),
                isTracked: !inSlot.isEmpty || measured.contains { $0.endedAt >= cursor && $0.endedAt < next },
                isFuture: slot.start > now
            ))
            cursor = next
        }
        return buckets
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
}

// MARK: - Sample data

extension ProgressDashboard {
    /// Placeholder content so the screen can be designed before there's real history. Previews only.
    static func sample(period: ProgressPeriod, now: Date, calendar: Calendar = .current) -> ProgressDashboard {
        ProgressDashboard(
            history: sampleHistory(now: now, calendar: calendar),
            assessments: [0, 9, 16].compactMap { daysAgo in
                calendar.date(byAdding: .day, value: -daysAgo, to: now).map { sampleAssessment(endingAt: $0) }
            },
            period: period,
            now: now,
            calendar: calendar
        )
    }

    /// About three sessions a week for the past five weeks.
    static func sampleHistory(now: Date, calendar: Calendar = .current) -> [CompletedSession] {
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

    static func sampleAssessment(endingAt end: Date) -> PostureAssessment {
        PostureAssessment(
            id: UUID(), startedAt: end.addingTimeInterval(-600), endedAt: end, activeSeconds: 600,
            framesAnalysed: 590, headFrames: 520, trunkFrames: 480,
            headForwardMedian: 22, headForwardShare: 0.44, trunkLeanMedian: 9, trunkLeanShare: 0.18
        )
    }
}
