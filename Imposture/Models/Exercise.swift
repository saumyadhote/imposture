import Foundation

nonisolated enum BodyArea: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case neck
    case shoulders
    case upperBack
    case back
    case hips
    case legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: "Neck"
        case .shoulders: "Shoulders"
        case .upperBack: "Upper back"
        case .back: "Back"
        case .hips: "Hips"
        case .legs: "Legs"
        }
    }

    var systemImage: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders: "figure.arms.open"
        case .upperBack: "figure.stand"
        case .back: "figure.flexibility"
        case .hips: "figure.cooldown"
        case .legs: "figure.walk"
        }
    }
}

extension BodyArea {
    /// The four posture concerns offered on Home, in display order. Each is backed by one
    /// body area, so its exercises are the ones already tagged with that area.
    static let concerns: [BodyArea] = [.neck, .shoulders, .back, .upperBack]

    /// The everyday name for the concern this area addresses, or nil if it isn't one.
    var concernTitle: String? {
        switch self {
        case .neck: "Tech Neck"
        case .shoulders: "Rounded Shoulders"
        case .back: "Hunch Back"
        case .upperBack: "Neck Hump"
        case .hips, .legs: nil
        }
    }

    /// One plain line describing what the concern feels or looks like.
    var concernSummary: String? {
        switch self {
        case .neck: "Head drifting forward over a screen."
        case .shoulders: "Shoulders rolling in towards the chest."
        case .back: "A rounded back after long hours sitting."
        case .upperBack: "Stiffness where the neck meets the upper back."
        case .hips, .legs: nil
        }
    }
}

nonisolated enum ExercisePosition: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case seated
    case standing
    case floor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seated: "Seated"
        case .standing: "Standing"
        case .floor: "On the floor"
        }
    }

    var systemImage: String {
        switch self {
        case .seated: "chair"
        case .standing: "figure.stand"
        case .floor: "figure.yoga"
        }
    }
}

/// How the catalogue groups exercises. Separate from body areas, which drive search and filters.
nonisolated enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case neck
    case strength
    case mobility
    case stretch
    case desk
    case legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: "Neck"
        case .strength: "Strength and stability"
        case .mobility: "Mobility"
        case .stretch: "Stretches"
        case .desk: "Desk stretches"
        case .legs: "Legs and balance"
        }
    }

    var systemImage: String {
        switch self {
        case .neck: "person.bust"
        case .strength: "figure.strengthtraining.functional"
        case .mobility: "figure.flexibility"
        case .stretch: "figure.cooldown"
        case .desk: "chair.lounge"
        case .legs: "figure.walk"
        }
    }
}

nonisolated enum Equipment: String, Codable, Hashable, Sendable {
    case none
    case chair
    case wall
    case doorway
    case mat
    case resistanceBand

    /// Short label for what the person needs, or nil when nothing is required.
    var title: String? {
        switch self {
        case .none: nil
        case .chair: "Chair"
        case .wall: "Wall"
        case .doorway: "Doorway"
        case .mat: "Mat"
        case .resistanceBand: "Resistance band"
        }
    }
}

nonisolated struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    var category: ExerciseCategory = .mobility
    let summary: String
    /// One short line shown while the exercise is running.
    var instruction: String = ""
    let bodyAreas: [BodyArea]
    let position: ExercisePosition
    let equipment: Equipment
    /// Default timed duration. Set per exercise in Library.json; initial values pending review.
    let durationSeconds: Int
    let repsGuide: String
    let bothSides: Bool
    /// Asset name, or nil while the artwork hasn't been drawn yet.
    let illustration: String?
    let illustrationDescription: String
    /// Bundled mascot demonstration video (without extension), or nil until it's rendered.
    var animation: String? = nil
    let steps: [String]
    let easier: [String]
    let cautions: [String]
    /// How to set up before starting.
    var startingPosition: String? = nil
    /// Hold or pacing guidance, when it isn't covered by the steps.
    var hold: String? = nil
    /// What the person should expect to feel.
    var feel: String? = nil
    /// How to do the second side, for exercises done on each side.
    var switchSides: String? = nil

    var duration: TimeInterval { TimeInterval(durationSeconds) }
}

nonisolated struct Routine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let exerciseIDs: [String]
    /// A short note shown before the routine starts.
    var intro: String? = nil
    /// Position in the ten-day programme, or nil for a stand-alone routine.
    var day: Int? = nil

    var isProgrammeDay: Bool { day != nil }

    /// Short routines offered after a programme day is already done.
    static let gentleMobilityID = "gentle-mobility"
    static let deskResetID = "desk-reset"
}

/// Bundled exercise content. Decoded once at launch.
nonisolated struct ExerciseLibrary: Codable, Sendable {
    let contentStatus: String
    let exercises: [Exercise]
    /// Stand-alone routines, such as Desk Reset.
    let routines: [Routine]
    /// The ten-day guided programme, in day order.
    let programme: [Routine]

    func exercise(id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    func exercises(in routine: Routine) -> [Exercise] {
        routine.exerciseIDs.compactMap(exercise(id:))
    }

    func exercises(in category: ExerciseCategory) -> [Exercise] {
        exercises.filter { $0.category == category }
    }

    /// Categories that have at least one exercise, in display order.
    var categories: [ExerciseCategory] {
        ExerciseCategory.allCases.filter { category in exercises.contains { $0.category == category } }
    }

    /// A programme day or a stand-alone routine.
    func routine(id: String) -> Routine? {
        programme.first { $0.id == id } ?? routines.first { $0.id == id }
    }
}
