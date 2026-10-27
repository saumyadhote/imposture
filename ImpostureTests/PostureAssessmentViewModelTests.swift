import AVFoundation
import Foundation
import Testing
@testable import Imposture

/// A camera that never touches hardware. Pose frames are fed in by the test.
final class MockCamera: CameraControlling {
    var access: CameraAccess
    var grantsAccess: Bool
    var failsToStart = false
    private(set) var isRunning = false
    private(set) var isUsingFrontCamera = true

    var previewSession: AVCaptureSession? { nil }

    init(access: CameraAccess = .authorized, grantsAccess: Bool = true) {
        self.access = access
        self.grantsAccess = grantsAccess
    }

    func requestAccess() async -> Bool {
        access = grantsAccess ? .authorized : .denied
        return grantsAccess
    }

    func start() async throws {
        if failsToStart { throw CameraError.unavailable }
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func switchCamera() async throws {
        isUsingFrontCamera.toggle()
    }

    func poseFrames(interval: TimeInterval) -> AsyncStream<PoseFrame> {
        AsyncStream { _ in }
    }
}

enum PoseFixtures {
    /// A person facing right, ear `headAngle`° ahead of the shoulder, shoulder `lean`° ahead of the hip.
    static func frame(headAngle: Double = 10, lean: Double = 5, at time: TimeInterval = 0) -> PoseFrame {
        func ahead(of base: BodyPoint, by degrees: Double, length: Double) -> BodyPoint {
            let r = degrees * .pi / 180
            return BodyPoint(x: base.x + sin(r) * length, y: base.y + cos(r) * length, confidence: 0.9)
        }
        let hip = BodyPoint(x: 300, y: 400, confidence: 0.9)
        let shoulder = ahead(of: hip, by: lean, length: 300)
        let ear = ahead(of: shoulder, by: headAngle, length: 120)
        let nose = BodyPoint(x: ear.x + 60, y: ear.y, confidence: 0.9)
        return PoseFrame(timestamp: time, joints: SideViewJoints(nose: nose, ear: ear, shoulder: shoulder, hip: hip))
    }
}

struct PostureMetricsTests {
    @Test("measures head-forward and lean angles from side-view joints")
    func angles() throws {
        let joints = try #require(PoseFixtures.frame(headAngle: 25, lean: 10).joints)
        let angles = PostureMetrics.angles(joints)
        #expect(abs((angles.headForward ?? 0) - 25) < 0.001)
        #expect(abs((angles.trunkLean ?? 0) - 10) < 0.001)
    }

    @Test("works whichever way the person faces")
    func mirrored() throws {
        var joints = try #require(PoseFixtures.frame(headAngle: 25, lean: 10).joints)
        for keyPath in [\SideViewJoints.nose, \.ear, \.shoulder, \.hip] {
            joints[keyPath: keyPath]?.x *= -1
        }
        #expect(abs((PostureMetrics.angles(joints).headForward ?? 0) - 25) < 0.001)
    }

    @Test("low-confidence or missing joints aren't measured")
    func lowConfidence() throws {
        var joints = try #require(PoseFixtures.frame().joints)
        joints.hip?.confidence = 0.1
        let angles = PostureMetrics.angles(joints)
        #expect(angles.headForward != nil)
        #expect(angles.trunkLean == nil)
        joints.nose = nil
        #expect(PostureMetrics.angles(joints) == PostureMetrics.Angles())
        #expect(PostureMetrics.framing(PoseFrame(timestamp: 0, joints: nil)) == .noPerson)
    }

    @Test("summarises frames as medians and shares beyond the reference angle")
    func summary() {
        let frames = (0..<30).map { PoseFixtures.frame(headAngle: $0 < 20 ? 30 : 10, lean: 5, at: Double($0)) }
            + (0..<10).map { PoseFrame(timestamp: Double($0 + 30), joints: nil) }
        let a = PostureMetrics.assessment(frames: frames, startedAt: .now, endedAt: .now, activeSeconds: 40)
        #expect(a.framesAnalysed == 40)
        #expect(a.headFrames == 30)
        #expect(abs((a.headForwardMedian ?? 0) - 30) < 0.001)
        #expect(abs((a.headForwardShare ?? 0) - 20.0 / 30.0) < 0.001)
        #expect(a.trunkLeanShare == 0)
        #expect(abs(a.visibleShare - 0.75) < 0.001)
    }

    @Test("too few usable frames gives no findings rather than a guess")
    func tooFewFrames() {
        let frames = (0..<5).map { PoseFixtures.frame(at: Double($0)) }
        let a = PostureMetrics.assessment(frames: frames, startedAt: .now, endedAt: .now, activeSeconds: 5)
        #expect(!a.hasFindings)
    }

    @Test("the report marks shoulder alignment as not assessed and compares with last time")
    func report() {
        let frames = (0..<30).map { PoseFixtures.frame(headAngle: 30, at: Double($0)) }
        let now = PostureMetrics.assessment(frames: frames, startedAt: .now, endedAt: .now, activeSeconds: 30)
        let earlier = PostureMetrics.assessment(
            frames: (0..<30).map { PoseFixtures.frame(headAngle: 20, at: Double($0)) },
            startedAt: .now, endedAt: .now, activeSeconds: 30
        )
        let analysis = PostureAnalysis(now, previous: earlier)
        #expect(analysis.findings.first { $0.title == "Shoulder alignment" }?.reliability == .notAssessed)
        #expect(analysis.findings.first?.trend == .worse("10° more than last time"))
        #expect(analysis.comparedWithPrevious)
    }
}

@MainActor
struct PostureAssessmentViewModelTests {
    let clock = TestClock()
    let camera = MockCamera()
    let store = InMemoryAssessmentStore()

    private func makeViewModel() -> PostureAssessmentViewModel {
        PostureAssessmentViewModel(camera: camera, record: { assessment in
            (try? store.add(assessment)) != nil
        }, clock: clock.function)
    }

    private func isReport(_ phase: PostureAssessmentViewModel.Phase) -> Bool {
        if case .report = phase { true } else { false }
    }

    @Test("starts the camera for positioning when access is granted")
    func prepare() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        #expect(viewModel.phase == .positioning)
        #expect(camera.isRunning)
    }

    @Test("handles denied, refused and missing cameras")
    func permissionStates() async {
        let denied = PostureAssessmentViewModel(camera: MockCamera(access: .denied), record: { _ in true })
        await denied.prepare()
        #expect(denied.phase == .denied)

        let refused = PostureAssessmentViewModel(camera: MockCamera(access: .notDetermined, grantsAccess: false), record: { _ in true })
        await refused.prepare()
        #expect(refused.phase == .denied)

        let missing = PostureAssessmentViewModel(camera: MockCamera(access: .unavailable), record: { _ in true })
        await missing.prepare()
        #expect(missing.phase == .unavailable)
    }

    @Test("a camera that fails to start shows an error")
    func startFailure() async {
        camera.failsToStart = true
        let viewModel = makeViewModel()
        await viewModel.prepare()
        #expect(viewModel.phase == .failed("The camera couldn't start."))
    }

    @Test("collects frames only while running, and pausing stops the clock")
    func pauseStopsTime() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.start()
        clock.advance(20)
        await viewModel.tickClock()
        #expect(viewModel.elapsed == 20)
        #expect(!viewModel.canFinish)

        viewModel.pause()
        clock.advance(100)
        await viewModel.tickClock()
        #expect(viewModel.elapsed == 20)
        viewModel.resume()
        clock.advance(15)
        await viewModel.tickClock()
        #expect(viewModel.elapsed == 35)
        #expect(viewModel.canFinish)
    }

    @Test("finishing analyses the frames, saves the result and shows the report")
    func finish() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.start()
        for second in 0..<40 {
            viewModel.ingest(PoseFixtures.frame(headAngle: 25, at: Double(second)))
        }
        clock.advance(40)
        await viewModel.finish()
        #expect(isReport(viewModel.phase))
        #expect(store.assessments.count == 1)
        #expect(store.assessments.first?.framesAnalysed == 40)
        #expect(!camera.isRunning)
    }

    @Test("frames seen while paused or positioning aren't counted")
    func ignoresPausedFrames() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.ingest(PoseFixtures.frame())
        #expect(viewModel.framing == .good)
        viewModel.start()
        viewModel.pause()
        for second in 0..<40 { viewModel.ingest(PoseFixtures.frame(at: Double(second))) }
        viewModel.resume()
        clock.advance(40)
        await viewModel.finish()
        #expect(viewModel.phase == .insufficient)
        #expect(store.assessments.isEmpty)
    }

    @Test("stops on its own at the chosen length")
    func autoFinish() async {
        let viewModel = makeViewModel()
        viewModel.length = .one
        await viewModel.prepare()
        viewModel.start()
        for second in 0..<60 { viewModel.ingest(PoseFixtures.frame(at: Double(second))) }
        clock.advance(61)
        await viewModel.tickClock()
        #expect(isReport(viewModel.phase))
        #expect(store.assessments.first?.activeSeconds == 60)
    }

    @Test("cancelling discards everything and returns to positioning")
    func cancel() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.start()
        for second in 0..<40 { viewModel.ingest(PoseFixtures.frame(at: Double(second))) }
        viewModel.cancel()
        #expect(viewModel.phase == .positioning)
        viewModel.start()
        clock.advance(40)
        await viewModel.finish()
        #expect(viewModel.phase == .insufficient)
    }

    @Test("a result that can't be saved still shows, flagged")
    func saveFailure() async {
        store.failNextAdd = true
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.start()
        for second in 0..<40 { viewModel.ingest(PoseFixtures.frame(at: Double(second))) }
        clock.advance(40)
        await viewModel.finish()
        #expect(isReport(viewModel.phase))
        #expect(viewModel.saveFailed)
    }
}
