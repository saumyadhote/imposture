import Foundation

/// An ordered list of exercises the session player walks through.
nonisolated struct SessionPlan: Codable, Hashable, Sendable {
    /// The routine this plan came from, or nil for a single-exercise session.
    let routineID: String?
    let title: String
    let exercises: [Exercise]

    /// Pause shown before each exercise so the person can get into position.
    static let getReadySeconds: TimeInterval = 5

    var totalDuration: TimeInterval {
        exercises.reduce(0) { $0 + $1.duration + Self.getReadySeconds }
    }

    /// Rounded minutes for display, never less than 1.
    var roundedMinutes: Int {
        max(1, Int((totalDuration / 60).rounded()))
    }

    var positions: Set<ExercisePosition> {
        Set(exercises.map(\.position))
    }

    init(routineID: String?, title: String, exercises: [Exercise]) {
        self.routineID = routineID
        self.title = title
        self.exercises = exercises
    }

    init(routine: Routine, library: ExerciseLibrary) {
        self.init(routineID: routine.id, title: routine.title, exercises: library.exercises(in: routine))
    }

    init(single exercise: Exercise) {
        self.init(routineID: nil, title: exercise.name, exercises: [exercise])
    }
}

/// Saved state of an unfinished session so it can be resumed after an interruption.
nonisolated struct SessionSnapshot: Codable, Hashable, Sendable {
    enum Stage: String, Codable, Sendable {
        case getReady
        case active
    }

    let plan: SessionPlan
    let index: Int
    let stage: Stage
    let elapsedInStage: TimeInterval
    let completedCount: Int
    let activeSeconds: TimeInterval
    let startedAt: Date
    let savedAt: Date

    /// Snapshots older than this are not offered for resuming.
    static let maximumAge: TimeInterval = 12 * 60 * 60

    func isResumable(at now: Date) -> Bool {
        now.timeIntervalSince(savedAt) < Self.maximumAge && index < plan.exercises.count
    }
}

/// A finished (or ended early) session, as shown in Progress.
nonisolated struct CompletedSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let routineID: String?
    let title: String
    let startedAt: Date
    let endedAt: Date
    let activeSeconds: TimeInterval
    let exercisesCompleted: Int
    let exercisesTotal: Int
    /// True when the session ran to its last exercise rather than being ended early.
    /// Skipped exercises (for example, no resistance band to hand) don't stop this.
    var reachedEnd: Bool = false

    var finishedAll: Bool { exercisesCompleted >= exercisesTotal }

    /// Whether this session counts as completing its programme day.
    var completesRoutine: Bool { reachedEnd || finishedAll }
}
