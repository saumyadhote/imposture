import Foundation

/// Where the person is in the ten-day programme, derived from session history.
/// Every day stays open: the status only guides, it never locks.
struct ProgrammeProgress: Equatable {
    enum Status: Equatable {
        case completed
        /// The recommended day: the first one not yet completed.
        case current
        case upcoming
    }

    let days: [Routine]
    let completedIDs: Set<String>
    /// Programme days completed on the same calendar day as `now`.
    let completedTodayIDs: Set<String>

    init(programme: [Routine], history: [CompletedSession], now: Date, calendar: Calendar = .current) {
        days = programme.sorted { ($0.day ?? 0) < ($1.day ?? 0) }
        let dayIDs = Set(programme.map(\.id))
        let completed = history.filter { session in
            session.completesRoutine && session.routineID.map(dayIDs.contains) == true
        }
        completedIDs = Set(completed.compactMap(\.routineID))
        completedTodayIDs = Set(completed.filter { calendar.isDate($0.endedAt, inSameDayAs: now) }.compactMap(\.routineID))
    }

    var current: Routine? {
        days.first { !completedIDs.contains($0.id) }
    }

    var completedCount: Int { completedIDs.count }
    var isComplete: Bool { !days.isEmpty && current == nil }
    var hasCompletedToday: Bool { !completedTodayIDs.isEmpty }

    func status(of day: Routine) -> Status {
        if completedIDs.contains(day.id) { return .completed }
        return day.id == current?.id ? .current : .upcoming
    }
}

/// A gentle suggestion shown when someone who already finished a programme day today
/// starts another one. They can always continue.
struct RecoveryOffer: Identifiable, Equatable {
    let id = UUID()
    /// The programme day they tried to start.
    let requested: Routine
    /// Gentle Mobility and Desk Reset, when they exist.
    let alternatives: [Routine]
}
