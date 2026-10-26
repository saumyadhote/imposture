import Foundation

/// Totals derived from session history for the Today and Progress screens.
struct ProgressSummary: Equatable {
    struct Day: Identifiable, Equatable {
        let date: Date
        let isActive: Bool
        let isToday: Bool
        var id: Date { date }
    }

    let week: [Day]
    let activeDaysThisWeek: Int
    let minutesThisWeek: Int
    let totalSessions: Int
    let totalMinutes: Int

    var isEmpty: Bool { totalSessions == 0 }

    init(history: [CompletedSession], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let activeDays = Set(history.map { calendar.startOfDay(for: $0.endedAt) })

        week = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return Day(date: date, isActive: activeDays.contains(date), isToday: date == today)
        }

        let thisWeek = history.filter { $0.endedAt >= weekStart }
        activeDaysThisWeek = week.filter(\.isActive).count
        minutesThisWeek = Self.minutes(thisWeek)
        totalSessions = history.count
        totalMinutes = Self.minutes(history)
    }

    private static func minutes(_ sessions: [CompletedSession]) -> Int {
        Int((sessions.reduce(0) { $0 + $1.activeSeconds } / 60).rounded())
    }
}
