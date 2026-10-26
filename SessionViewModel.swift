import Foundation
import Observation

/// Drives a guided session: get ready → exercise → next, with pause, previous, next and end.
///
/// Time is measured from timestamps rather than by counting ticks, so the
/// remaining time stays correct even if ticks are delayed.
@MainActor @Observable
final class SessionViewModel: Identifiable {
    typealias Stage = SessionSnapshot.Stage

    enum Status: Equatable {
        case running
        case paused
        case finished(completedAll: Bool)
    }

    let id = UUID()
    let plan: SessionPlan
    let startedAt: Date

    private(set) var index: Int
    private(set) var stage: Stage
    private(set) var status: Status
    private(set) var completedCount: Int
    /// The latest time seen by the session; drives view updates.
    private(set) var now: Date
    /// Set once the session ends, if enough was done to be worth recording.
    private(set) var result: CompletedSession?

    private var accumulatedInStage: TimeInterval
    private var runningSince: Date?
    private var activeSecondsBeforeStage: TimeInterval
    private let clock: () -> Date

    /// Sessions shorter than this are not saved to history.
    static let minimumRecordedSeconds: TimeInterval = 15

    init(plan: SessionPlan, clock: @escaping () -> Date = Date.init) {
        self.plan = plan
        self.clock = clock
        let start = clock()
        startedAt = start
        now = start
        index = 0
        stage = .getReady
        status = .running
        completedCount = 0
        accumulatedInStage = 0
        activeSecondsBeforeStage = 0
        runningSince = start
    }

    /// Restores an interrupted session. It always comes back paused so the
    /// person can get into position before the timer moves.
    init(snapshot: SessionSnapshot, clock: @escaping () -> Date = Date.init) {
        plan = snapshot.plan
        self.clock = clock
        startedAt = snapshot.startedAt
        now = clock()
        index = min(snapshot.index, max(0, snapshot.plan.exercises.count - 1))
        stage = snapshot.stage
        status = .paused
        completedCount = snapshot.completedCount
        accumulatedInStage = snapshot.elapsedInStage
        activeSecondsBeforeStage = snapshot.activeSeconds
        runningSince = nil
    }

    // MARK: - Derived state

    var currentExercise: Exercise { plan.exercises[index] }

    var nextExercise: Exercise? {
        plan.exercises.indices.contains(index + 1) ? plan.exercises[index + 1] : nil
    }

    var isFinished: Bool {
        if case .finished = status { true } else { false }
    }

    var isPaused: Bool { status == .paused }

    var stageDuration: TimeInterval {
        stage == .getReady ? SessionPlan.getReadySeconds : currentExercise.duration
    }

    var elapsedInStage: TimeInterval {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return min(stageDuration, accumulatedInStage + running)
    }

    var remainingInStage: TimeInterval { max(0, stageDuration - elapsedInStage) }

    /// Whole seconds left, rounded up so "1" shows until the stage really ends.
    var remainingSeconds: Int { Int(remainingInStage.rounded(.up)) }

    var stageProgress: Double {
        stageDuration > 0 ? elapsedInStage / stageDuration : 1
    }

    /// For exercises done on each side, true once the halfway point passes.
    var isOnSecondSide: Bool {
        currentExercise.bothSides && stage == .active && elapsedInStage >= stageDuration / 2
    }

    var canGoBack: Bool { index > 0 || stage == .active }

    var isLastExercise: Bool { index == plan.exercises.count - 1 }

    /// True once the session has run past its last exercise (rather than being ended early).
    private(set) var reachedEnd = false

    /// Total seconds spent in the active part of exercises, including the current one.
    var activeSeconds: TimeInterval {
        activeSecondsBeforeStage + (stage == .active ? elapsedInStage : 0)
    }

    /// Changes whenever the person should be told something new: a new
    /// exercise, the start of movement, or a side switch.
    var cueKey: String {
        "\(index)-\(stage.rawValue)-\(isOnSecondSide)-\(isFinished)"
    }

    // MARK: - Running

    /// Ticks until the session finishes or the calling task is cancelled.
    func run() async {
        while !Task.isCancelled && !isFinished {
            try? await Task.sleep(for: .milliseconds(200))
            tick()
        }
    }

    func tick() {
        now = clock()
        guard status == .running, elapsedInStage >= stageDuration else { return }
        advanceStage()
    }

    // MARK: - Controls

    func pause() {
        guard status == .running else { return }
        now = clock()
        accumulatedInStage = elapsedInStage
        runningSince = nil
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        now = clock()
        runningSince = now
        status = .running
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    /// Skips the get-ready countdown and starts moving now.
    func startNow() {
        guard stage == .getReady, !isFinished else { return }
        beginStage(.active)
    }

    /// Moves to the next exercise without counting the current one as done.
    func skip() {
        guard !isFinished else { return }
        now = clock()
        bankActiveTime()
        moveToExercise(index + 1)
    }

    /// Goes to the previous exercise, or restarts the first one.
    func goBack() {
        guard !isFinished else { return }
        now = clock()
        bankActiveTime()
        if index > 0 {
            index -= 1
        }
        beginStage(.getReady)
    }

    func end() {
        guard !isFinished else { return }
        now = clock()
        bankActiveTime()
        finish()
    }

    func snapshot() -> SessionSnapshot? {
        guard !isFinished else { return nil }
        now = clock()
        return SessionSnapshot(
            plan: plan,
            index: index,
            stage: stage,
            elapsedInStage: elapsedInStage,
            completedCount: completedCount,
            activeSeconds: activeSecondsBeforeStage,
            startedAt: startedAt,
            savedAt: clock()
        )
    }

    // MARK: - Transitions

    private func advanceStage() {
        switch stage {
        case .getReady:
            beginStage(.active)
        case .active:
            bankActiveTime()
            completedCount += 1
            moveToExercise(index + 1)
        }
    }

    private func moveToExercise(_ newIndex: Int) {
        guard plan.exercises.indices.contains(newIndex) else {
            reachedEnd = true
            finish()
            return
        }
        index = newIndex
        beginStage(.getReady)
    }

    private func beginStage(_ newStage: Stage) {
        now = clock()
        stage = newStage
        accumulatedInStage = 0
        runningSince = status == .running ? now : nil
    }

    /// Adds time spent in the current active stage to the running total.
    /// Callers must refresh `now` first so the elapsed time is current.
    private func bankActiveTime() {
        if stage == .active {
            activeSecondsBeforeStage += elapsedInStage
        }
        accumulatedInStage = 0
        runningSince = status == .running ? now : nil
    }

    private func finish() {
        now = clock()
        runningSince = nil
        status = .finished(completedAll: completedCount >= plan.exercises.count)
        let total = activeSecondsBeforeStage
        guard total >= Self.minimumRecordedSeconds else { return }
        result = CompletedSession(
            id: UUID(),
            routineID: plan.routineID,
            title: plan.title,
            startedAt: startedAt,
            endedAt: now,
            activeSeconds: total,
            exercisesCompleted: completedCount,
            exercisesTotal: plan.exercises.count,
            reachedEnd: reachedEnd
        )
    }
}
