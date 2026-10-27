import Foundation
import Observation

/// How long an assessment runs before it finishes on its own.
enum AssessmentLength: Int, CaseIterable, Identifiable, Sendable {
    case one = 1
    case five = 5
    case ten = 10

    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    var title: String { "\(rawValue) min" }
}

/// A side-view seated posture assessment: position the phone, sit as usual for up to
/// ten minutes, then get a report built from on-device pose estimates.
///
/// Only joint positions are kept while it runs, in memory. No photos or video are taken.
@MainActor @Observable
final class PostureAssessmentViewModel {
    enum Phase: Equatable {
        case idle
        case requestingAccess
        case denied
        case unavailable
        /// Camera live, helping the person get into frame.
        case positioning
        case assessing
        case processing
        case report(PostureAssessment)
        /// Finished, but too little of the person was visible to say anything.
        case insufficient
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    private(set) var framing: PostureMetrics.Framing = .noPerson
    private(set) var isUsingFrontCamera: Bool
    /// The latest time seen; drives the timer display.
    private(set) var now: Date
    /// Set when the result couldn't be stored; the report still shows.
    private(set) var saveFailed = false
    var length: AssessmentLength = .ten

    /// Seconds between analysed frames.
    static let frameInterval: TimeInterval = 1
    /// Finishing is allowed after this much assessment time.
    static let minimumSeconds: TimeInterval = 30

    let camera: CameraControlling
    private let record: (PostureAssessment) -> Bool
    private let clock: () -> Date
    private let tick: Duration

    @ObservationIgnored private var frames: [PoseFrame] = []
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?

    init(
        camera: CameraControlling,
        record: @escaping (PostureAssessment) -> Bool,
        clock: @escaping () -> Date = Date.init,
        tick: Duration = .milliseconds(500)
    ) {
        self.camera = camera
        self.record = record
        self.clock = clock
        self.tick = tick
        now = clock()
        isUsingFrontCamera = camera.isUsingFrontCamera
    }

    // MARK: - Derived

    var elapsed: TimeInterval {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return min(length.seconds, accumulated + running)
    }

    var remainingSeconds: Int { Int((length.seconds - elapsed).rounded(.up)) }
    var progress: Double { length.seconds > 0 ? elapsed / length.seconds : 0 }
    var canFinish: Bool { phase == .assessing && elapsed >= Self.minimumSeconds }
    var isCameraLive: Bool { phase == .positioning || phase == .assessing }

    // MARK: - Setup

    /// Asks for camera access if needed, then starts the camera for positioning.
    func prepare() async {
        guard phase == .idle || phase == .denied else { return }
        switch camera.access {
        case .unavailable:
            phase = .unavailable
            return
        case .denied:
            phase = .denied
            return
        case .notDetermined:
            phase = .requestingAccess
            guard await camera.requestAccess() else {
                phase = .denied
                return
            }
        case .authorized:
            break
        }
        await startCamera()
    }

    /// Reads pose frames and keeps time until the calling task is cancelled.
    func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.consumeFrames() }
            group.addTask { await self.keepTime() }
        }
    }

    func switchCamera() async {
        guard phase == .positioning else { return }
        do {
            try await camera.switchCamera()
            isUsingFrontCamera = camera.isUsingFrontCamera
        } catch {
            phase = .failed("Couldn't switch cameras.")
        }
    }

    // MARK: - Assessment

    func start() {
        guard phase == .positioning else { return }
        frames = []
        accumulated = 0
        now = clock()
        startedAt = now
        runningSince = now
        isPaused = false
        saveFailed = false
        phase = .assessing
    }

    func pause() {
        guard phase == .assessing, !isPaused else { return }
        now = clock()
        accumulated = elapsed
        runningSince = nil
        isPaused = true
    }

    func resume() {
        guard phase == .assessing, isPaused else { return }
        now = clock()
        runningSince = now
        isPaused = false
    }

    /// Stops without a result. Nothing collected is kept.
    func cancel() {
        guard phase == .assessing else { return }
        frames = []
        accumulated = 0
        runningSince = nil
        isPaused = false
        phase = .positioning
    }

    /// Ends the assessment and analyses what was collected.
    func finish() async {
        guard phase == .assessing else { return }
        now = clock()
        accumulated = elapsed
        runningSince = nil
        phase = .processing
        camera.stop()

        let collected = frames
        frames = []
        let started = startedAt ?? now
        let ended = now
        let active = accumulated
        let assessment = await Task.detached(priority: .userInitiated) {
            PostureMetrics.assessment(frames: collected, startedAt: started, endedAt: ended, activeSeconds: active)
        }.value

        guard assessment.hasFindings else {
            phase = .insufficient
            return
        }
        saveFailed = !record(assessment)
        phase = .report(assessment)
    }

    /// Back to positioning for another assessment.
    func startOver() async {
        frames = []
        accumulated = 0
        isPaused = false
        await startCamera()
    }

    func retryAfterFailure() async {
        guard case .failed = phase else { return }
        await startCamera()
    }

    /// Pauses an assessment and stops the camera, e.g. when the screen or app goes away.
    func suspend() {
        pause()
        camera.stop()
    }

    /// Restarts the camera after `suspend()`. The assessment stays paused.
    func resumeCamera() async {
        guard isCameraLive else { return }
        do {
            try await camera.start()
        } catch {
            phase = .failed("The camera couldn't start.")
        }
    }

    // MARK: - Private

    private func startCamera() async {
        do {
            try await camera.start()
            phase = .positioning
        } catch {
            phase = .failed("The camera couldn't start.")
        }
    }

    private func consumeFrames() async {
        for await frame in camera.poseFrames(interval: Self.frameInterval) {
            ingest(frame)
        }
    }

    func ingest(_ frame: PoseFrame) {
        framing = PostureMetrics.framing(frame)
        if phase == .assessing, !isPaused {
            frames.append(frame)
        }
    }

    private func keepTime() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: tick)
            await tickClock()
        }
    }

    func tickClock() async {
        now = clock()
        if phase == .assessing, !isPaused, elapsed >= length.seconds {
            await finish()
        }
    }
}
