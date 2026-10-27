import Foundation

/// One card in Home's recommended-sessions carousel.
struct SessionRecommendation: Identifiable, Equatable {
    let routine: Routine
    /// Short uppercase-able label, e.g. "Day 2 · Your 10-Day Reset" or "Quick reset".
    let label: String
    let description: String
    let minutes: Int
    /// True for the programme's current day, which leads the carousel.
    let isProgrammeDay: Bool

    var id: String { routine.id }
}

/// Builds the carousel: today's programme day first, then every stand-alone guided session.
/// Labels and descriptions come from the routines' own exercises, never invented copy.
enum SessionRecommendations {
    static func make(
        programme: ProgrammeProgress,
        routines: [Routine],
        plan: (Routine) -> SessionPlan?
    ) -> [SessionRecommendation] {
        var cards: [SessionRecommendation] = []
        if let day = programme.current, let dayPlan = plan(day) {
            cards.append(SessionRecommendation(
                routine: day,
                label: "Day \(day.day ?? 1) · Your 10-Day Reset",
                description: exerciseList(dayPlan.exercises),
                minutes: dayPlan.roundedMinutes,
                isProgrammeDay: true
            ))
        }
        for routine in routines where !cards.contains(where: { $0.id == routine.id }) {
            guard let routinePlan = plan(routine), !routinePlan.exercises.isEmpty else { continue }
            cards.append(SessionRecommendation(
                routine: routine,
                label: label(for: routinePlan),
                description: routine.summary,
                minutes: routinePlan.roundedMinutes,
                isProgrammeDay: false
            ))
        }
        return cards
    }

    /// "Quick reset" for five minutes or less; otherwise named after the routine's main kind of exercise.
    static func label(for plan: SessionPlan) -> String {
        if plan.roundedMinutes <= 5 { return "Quick reset" }
        switch dominantCategory(of: plan.exercises) {
        case .neck: return "Focus session"
        case .mobility: return "Mobility"
        case .stretch: return "Stretch"
        case .desk: return "Desk break"
        case .strength, .legs, nil: return "Strength"
        }
    }

    static func dominantCategory(of exercises: [Exercise]) -> ExerciseCategory? {
        let counts = Dictionary(grouping: exercises, by: \.category).mapValues(\.count)
        // Ties go to the category that appears first in the routine.
        return exercises.map(\.category).max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }

    /// "Chin Tucks, Scapular Retraction and 2 more."
    static func exerciseList(_ exercises: [Exercise]) -> String {
        let names = exercises.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return "\(names[0])."
        case 2: return "\(names[0]) and \(names[1])."
        default: return "\(names[0]), \(names[1]) and \(names.count - 2) more."
        }
    }
}
