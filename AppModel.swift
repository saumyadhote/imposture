import Foundation
import Observation

/// App-wide state shared by every tab: content, preferences, history and the
/// session currently on screen.
@MainActor @Observable
final class AppModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var loadState: LoadState = .loading
    private(set) var library: ExerciseLibrary?
    private(set) var preferences: UserPreferences
    private(set) var history: [CompletedSession] = []
    private(set) var historyError: String?
    /// Posture assessments, newest first.
    private(set) var assessments: [PostureAssessment] = []
    private(set) var assessmentsError: String?
    /// Shown as a sheet when another programme day is started after finishing one today.
    var recoveryOffer: RecoveryOffer?
    /// An interrupted session that can be resumed from Today.
    private(set) var resumableSnapshot: SessionSnapshot?
    /// The session shown full screen, if any.
    var activeSession: SessionViewModel?
    /// The session that just ended; Today shows a short confirmation for it.
    private(set) var lastFinishedSession: CompletedSession?
    /// Increases each time a finished session hands back to Home, so tabs and stacks reset.
    private(set) var returnHomeCount = 0

    private let libraryService: ExerciseLibraryProviding
    private let preferencesStore: PreferencesStoring
    private let historyStore: SessionHistoryStoring?
    private let snapshotStore: SessionSnapshotStoring
    let assessmentStore: PostureAssessmentStoring?
    let reminders: ReminderScheduling
    private let clock: () -> Date
    private let calendar: Calendar
    /// The plan chosen in the recovery sheet, started once the sheet has gone.
    @ObservationIgnored private var planAfterRecoverySheet: SessionPlan?

    init(
        libraryService: ExerciseLibraryProviding,
        preferencesStore: PreferencesStoring,
        historyStore: SessionHistoryStoring?,
        snapshotStore: SessionSnapshotStoring,
        assessmentStore: PostureAssessmentStoring? = nil,
        reminders: ReminderScheduling,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.libraryService = libraryService
        self.preferencesStore = preferencesStore
        self.historyStore = historyStore
        self.snapshotStore = snapshotStore
        self.assessmentStore = assessmentStore
        self.reminders = reminders
        self.clock = clock
        self.calendar = calendar
        preferences = preferencesStore.load()
    }

    // MARK: - Loading

    func load() {
        loadState = .loading
        do {
            library = try libraryService.loadLibrary()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
        reloadHistory()
        reloadAssessments()
        if let snapshot = snapshotStore.load(), snapshot.isResumable(at: clock()) {
            resumableSnapshot = snapshot
        } else {
            snapshotStore.clear()
        }
    }

    func reloadHistory() {
        guard let historyStore else {
            historyError = "Your progress can't be saved on this device right now."
            return
        }
        do {
            history = try historyStore.fetchAll()
            historyError = nil
        } catch {
            historyError = "Your progress couldn't be loaded."
        }
    }

    func reloadAssessments() {
        guard let assessmentStore else {
            assessmentsError = "Posture results can't be saved on this device right now."
            return
        }
        do {
            assessments = try assessmentStore.fetchAll()
            assessmentsError = nil
        } catch {
            assessmentsError = "Your posture results couldn't be loaded."
        }
    }

    /// Saves a finished assessment. Returns false if it couldn't be stored.
    @discardableResult
    func record(_ assessment: PostureAssessment) -> Bool {
        do {
            guard let assessmentStore else { throw CocoaError(.fileWriteUnknown) }
            try assessmentStore.add(assessment)
            reloadAssessments()
            return true
        } catch {
            reloadAssessments()
            assessmentsError = "This posture result couldn't be saved."
            return false
        }
    }

    // MARK: - Derived

    var programme: ProgrammeProgress {
        ProgrammeProgress(programme: library?.programme ?? [], history: history, now: clock(), calendar: calendar)
    }

    /// A programme day suited to a posture result, from the existing ten days.
    /// Head-forward findings point to the neck days, upper-body lean to the upper-back days;
    /// otherwise it's the person's next day. Days already done give way to their follow-up.
    func recommendedDay(for assessment: PostureAssessment) -> Routine? {
        let progress = programme
        func firstOpen(_ ids: [String]) -> Routine? {
            let days = ids.compactMap { library?.routine(id: $0) }
            return days.first { !progress.completedIDs.contains($0.id) } ?? days.last
        }
        if (assessment.headForwardShare ?? 0) >= 0.3 {
            return firstOpen(["day-1", "day-4"])
        }
        if (assessment.trunkLeanShare ?? 0) >= 0.3 {
            return firstOpen(["day-2", "day-5"])
        }
        return progress.current ?? progress.days.last
    }

    var todaysRoutine: Routine? {
        guard let library else { return nil }
        return RoutineRecommender(library: library).recommendation(for: preferences, on: clock())
    }

    var quickPicks: [Routine] {
        guard let library else { return [] }
        let todayID = todaysRoutine?.id
        return RoutineRecommender(library: library)
            .rankedRoutines(for: preferences)
            .filter { $0.id != todayID }
    }

    var progress: ProgressSummary {
        ProgressSummary(history: history, now: clock())
    }

    func plan(for routine: Routine) -> SessionPlan? {
        library.map { SessionPlan(routine: routine, library: $0) }
    }

    // MARK: - Preferences

    func updatePreferences(_ update: (inout UserPreferences) -> Void) {
        update(&preferences)
        preferencesStore.save(preferences)
    }

    func completeOnboarding(with draft: UserPreferences) {
        var finished = draft
        finished.hasCompletedOnboarding = true
        preferences = finished
        preferencesStore.save(finished)
    }

    // MARK: - Sessions

    /// Starts a routine, or for a programme day started after another day was finished
    /// today, first suggests something gentler (at most once a day).
    func startRoutine(_ routine: Routine) {
        guard let plan = plan(for: routine) else { return }
        if routine.isProgrammeDay, shouldOfferRecovery(before: routine) {
            updatePreferences { $0.recoveryOfferShownOn = clock() }
            let alternatives = [Routine.gentleMobilityID, Routine.deskResetID].compactMap { library?.routine(id: $0) }
            recoveryOffer = RecoveryOffer(requested: routine, alternatives: alternatives)
            return
        }
        start(plan)
    }

    func shouldOfferRecovery(before routine: Routine) -> Bool {
        guard routine.isProgrammeDay else { return false }
        if let shown = preferences.recoveryOfferShownOn, calendar.isDate(shown, inSameDayAs: clock()) {
            return false
        }
        return !programme.completedTodayIDs.subtracting([routine.id]).isEmpty
    }

    /// Chooses a routine in the recovery sheet. It starts once the sheet is dismissed.
    func chooseFromRecoveryOffer(_ routine: Routine) {
        planAfterRecoverySheet = plan(for: routine)
        recoveryOffer = nil
    }

    /// Called when the recovery sheet goes away, however it was dismissed.
    func recoverySheetDismissed() {
        recoveryOffer = nil
        guard let plan = planAfterRecoverySheet else { return }
        planAfterRecoverySheet = nil
        start(plan)
    }

    func start(_ plan: SessionPlan) {
        guard !plan.exercises.isEmpty else { return }
        discardResumableSession()
        lastFinishedSession = nil
        activeSession = SessionViewModel(plan: plan, clock: clock)
    }

    func resumeInterruptedSession() {
        guard let snapshot = resumableSnapshot else { return }
        resumableSnapshot = nil
        activeSession = SessionViewModel(snapshot: snapshot, clock: clock)
    }

    func discardResumableSession() {
        resumableSnapshot = nil
        snapshotStore.clear()
    }

    /// Saves where the person is so the session survives the app closing.
    func saveProgress(of session: SessionViewModel) {
        if let snapshot = session.snapshot() {
            snapshotStore.save(snapshot)
        }
    }

    /// Called when the session screen goes away, finished or not.
    func sessionDismissed(_ session: SessionViewModel) {
        defer { activeSession = nil }
        guard session.isFinished else {
            // Closed without ending (should not normally happen): keep it resumable.
            saveProgress(of: session)
            resumableSnapshot = session.snapshot()
            return
        }
        snapshotStore.clear()
        returnHomeCount += 1
        guard let result = session.result else { return }
        lastFinishedSession = result
        do {
            try historyStore?.add(result)
            reloadHistory()
        } catch {
            reloadHistory()
            historyError = "This session couldn't be saved."
        }
    }

    func dismissFinishedConfirmation() {
        lastFinishedSession = nil
    }

    func resetProgress() {
        discardResumableSession()
        do {
            try historyStore?.deleteAll()
            try assessmentStore?.deleteAll()
            reloadHistory()
            reloadAssessments()
        } catch {
            reloadHistory()
            historyError = "Your progress couldn't be reset. Please try again."
        }
    }
}
