import Foundation

/// Picks today's suggested routine from the person's preferences.
/// Deliberately simple and predictable: no hidden scoring the person can't understand.
struct RoutineRecommender {
    let library: ExerciseLibrary
    var calendar: Calendar = .current

    /// Routines that fit the person's position preference, best match first.
    func rankedRoutines(for preferences: UserPreferences) -> [Routine] {
        let candidates: [Candidate] = library.routines.map { routine in
            let plan = SessionPlan(routine: routine, library: library)
            return Candidate(routine: routine, plan: plan, score: score(plan, preferences))
        }
        let eligible = candidates.filter { fits($0.plan, preferences.positionPreference) }
        let pool = eligible.isEmpty ? candidates : eligible
        return pool.sorted(by: Candidate.ranksBefore).map(\.routine)
    }

    private struct Candidate {
        let routine: Routine
        let plan: SessionPlan
        let score: Double

        static func ranksBefore(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.routine.id < rhs.routine.id
        }
    }

    /// Alternates between the two best matches day to day, so the suggestion
    /// varies without drifting away from what the person asked for.
    func recommendation(for preferences: UserPreferences, on date: Date) -> Routine? {
        let ranked = rankedRoutines(for: preferences)
        guard !ranked.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return ranked[day % min(2, ranked.count)]
    }

    private func fits(_ plan: SessionPlan, _ preference: PositionPreference) -> Bool {
        switch preference {
        case .seatedOnly: plan.positions == [.seated]
        case .any: true
        }
    }

    private func score(_ plan: SessionPlan, _ preferences: UserPreferences) -> Double {
        let minutesOff = abs(Double(plan.roundedMinutes - preferences.sessionLength.targetMinutes))
        let areas = Set(plan.exercises.flatMap(\.bodyAreas))
        let focusMatches = Double(areas.intersection(preferences.focusAreas).count)
        return focusMatches - minutesOff
    }
}
