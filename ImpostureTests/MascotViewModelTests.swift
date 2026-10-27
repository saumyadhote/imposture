import Foundation
import Testing
@testable import Imposture

/// Feeds a fixed list of samples, then finishes.
struct StubTiltSource: TiltSource {
    var isAvailable = true
    var readings: [TiltSample] = []

    func samples() -> AsyncStream<TiltSample> {
        AsyncStream { continuation in
            readings.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

/// `seconds` of samples at 60 Hz, all at the same tilt.
private func steadyTilt(_ roll: Double, for seconds: Double, startingAt start: TimeInterval = 0) -> [TiltSample] {
    let count = Int(seconds * 60)
    return (0..<count).map { TiltSample(roll: roll, timestamp: start + Double($0) / 60) }
}

struct TiltFilterTests {
    @Test("small tilts inside the dead zone stay neutral")
    func deadZone() {
        var filter = TiltFilter()
        for _ in 0..<120 { filter.update(roll: 0.2, dt: 1.0 / 60) }
        #expect(filter.value == 0)
    }

    @Test("large tilts are clamped to the maximum lean")
    func clamped() {
        var filter = TiltFilter()
        for _ in 0..<600 { filter.update(roll: 90, dt: 1.0 / 60) }
        #expect(filter.value <= filter.maxLean)
        #expect(filter.value > filter.maxLean - 0.01)
    }

    @Test("a sudden tilt is smoothed rather than applied at once")
    func smoothed() {
        var filter = TiltFilter()
        let target = filter.target(forRoll: 20)
        let first = filter.update(roll: 20, dt: 1.0 / 60)
        #expect(first > 0)
        #expect(first < target * 0.2)
    }

    @Test("tilting the other way leans the other way")
    func symmetric() {
        let filter = TiltFilter()
        #expect(filter.target(forRoll: -20) == -filter.target(forRoll: 20))
        #expect(filter.target(forRoll: -20) < 0)
    }

    @Test("returning the phone to level returns to exactly neutral")
    func returnsToNeutral() {
        var filter = TiltFilter()
        for _ in 0..<60 { filter.update(roll: 30, dt: 1.0 / 60) }
        for _ in 0..<120 { filter.update(roll: 0, dt: 1.0 / 60) }
        #expect(filter.value == 0)
    }

    @Test("a zero time step changes nothing")
    func zeroStep() {
        var filter = TiltFilter()
        filter.update(roll: 30, dt: 0)
        #expect(filter.value == 0)
    }
}

@MainActor
struct MascotViewModelTests {
    @Test("starts slouched and neutral")
    func initialState() {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource())
        #expect(viewModel.pose == .slouched)
        #expect(viewModel.lean == 0)
        #expect(viewModel.resetCount == 0)
    }

    @Test("lean follows phone tilt")
    func followsTilt() {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource())
        steadyTilt(25, for: 1).forEach(viewModel.ingest)
        #expect(viewModel.lean > 2)
        #expect(viewModel.lean <= TiltFilter().maxLean)
    }

    @Test("tapping sits the mascot up, then it slouches again")
    func resetThenRelax() async throws {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource(), uprightHold: .milliseconds(20))
        viewModel.resetPosture()
        #expect(viewModel.pose == .upright)
        #expect(viewModel.resetCount == 1)

        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.pose == .slouched)
    }

    @Test("tapping again while upright extends the hold")
    func repeatedTapExtendsHold() async throws {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource(), uprightHold: .milliseconds(400))
        viewModel.resetPosture()
        try await Task.sleep(for: .milliseconds(250))
        viewModel.resetPosture()
        try await Task.sleep(for: .milliseconds(250))

        #expect(viewModel.pose == .upright, "500 ms after the first tap, but only 250 ms after the second")
        #expect(viewModel.resetCount == 2)
    }

    @Test("tilt does not override the reset")
    func tiltYieldsToReset() {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource(), uprightHold: .seconds(60))
        steadyTilt(30, for: 1).forEach(viewModel.ingest)
        #expect(viewModel.lean > 2)

        viewModel.resetPosture()
        // The phone stays tilted, but the mascot holds its reset.
        steadyTilt(30, for: 0.5, startingAt: 1).forEach(viewModel.ingest)
        #expect(viewModel.lean == 0)
    }

    @Test("tilt fades back in gradually after the reset ends")
    func tiltReturnsGradually() async throws {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource(), uprightHold: .milliseconds(10))
        steadyTilt(30, for: 1).forEach(viewModel.ingest)
        let fullLean = viewModel.lean

        viewModel.resetPosture()
        steadyTilt(30, for: 0.5, startingAt: 1).forEach(viewModel.ingest)
        try await Task.sleep(for: .milliseconds(200))
        #expect(viewModel.pose == .slouched)

        steadyTilt(30, for: 0.3, startingAt: 1.5).forEach(viewModel.ingest)
        #expect(viewModel.lean > 0)
        #expect(viewModel.lean < fullLean * 0.5, "Should not snap straight back to full lean")
    }

    @Test("tracking settles to neutral when the feed ends")
    func settlesWhenTrackingStops() async {
        let viewModel = MascotViewModel(tiltSource: StubTiltSource(readings: steadyTilt(30, for: 1)))
        await viewModel.trackTilt()
        #expect(viewModel.lean == 0)
    }

    @Test("does nothing when motion is unavailable")
    func unavailable() async {
        let source = StubTiltSource(isAvailable: false, readings: steadyTilt(30, for: 1))
        let viewModel = MascotViewModel(tiltSource: source)
        await viewModel.trackTilt()
        #expect(viewModel.lean == 0)
    }
}

struct SlouchPoseTests {
    @Test("rest is hunched further forward; straight bends back")
    func spine() {
        #expect(SlouchPose.spine(straightness: 0) == SlouchPose.restingHunch)
        #expect(SlouchPose.spine(straightness: 1) == SlouchPose.uprightBend)
        #expect(SlouchPose.spine(straightness: 0.5) < SlouchPose.restingHunch)
        #expect(SlouchPose.spine(straightness: -1) == SlouchPose.restingHunch, "Never bends past the resting hunch")
    }

    @Test("dragging up straightens; down does nothing; past the top rubber-bands")
    func drag() {
        #expect(SlouchPose.straightness(forDrag: 0) == 0)
        #expect(SlouchPose.straightness(forDrag: 50) == 0)
        #expect(abs(SlouchPose.straightness(forDrag: -75) - 0.5) < 0.0001)
        #expect(SlouchPose.straightness(forDrag: -150) == 1)
        let far = SlouchPose.straightness(forDrag: -1000)
        #expect(far > 1 && far <= SlouchPose.maxStretch)
    }

    @Test("releasing past the threshold stands up")
    func release() {
        #expect(!SlouchPose.shouldStand(afterReleaseAt: 0.2))
        #expect(SlouchPose.shouldStand(afterReleaseAt: 0.6))
    }

    @Test("head nods with tilt and lifts when straight")
    func nod() {
        #expect(SlouchPose.nod(leanFraction: 1, straightness: 0) == SlouchPose.maxNod)
        #expect(SlouchPose.nod(leanFraction: 0, straightness: 1) == SlouchPose.uprightHeadLift)
        #expect(SlouchPose.nod(leanFraction: 0, straightness: 2) == SlouchPose.uprightHeadLift, "Lift is capped")
    }
}
