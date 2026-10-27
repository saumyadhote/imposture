import Foundation
import Observation

/// How the mascot is sitting.
enum MascotPose: Equatable {
    case slouched
    case upright
}

/// Drives the Home mascot: a lean from phone tilt, and a tap-to-sit-up reset.
///
/// The two are independent. Tilt is smoothed here and applied directly by the
/// view; the pose is animated by the view. While the mascot is upright, tilt
/// fades out quickly and only fades back in once it relaxes, so the sensor never
/// fights the reset.
@MainActor @Observable
final class MascotViewModel {
    /// Tilt-driven lean in degrees, smoothed and clamped. Positive leans toward the desk.
    private(set) var lean = 0.0
    private(set) var pose: MascotPose = .slouched
    /// Increases on every reset tap. Drives haptics.
    private(set) var resetCount = 0

    /// `lean` as a fraction of the largest possible lean, from -1 to 1.
    var leanFraction: Double {
        filter.maxLean > 0 ? lean / filter.maxLean : 0
    }

    /// How quickly tilt gives way when the mascot sits up, and returns afterwards.
    private static let tiltYieldDuration: TimeInterval = 0.2
    private static let tiltReturnDuration: TimeInterval = 1.2

    @ObservationIgnored private var filter = TiltFilter()
    @ObservationIgnored private var tiltInfluence = 1.0
    @ObservationIgnored private var lastSampleTime: TimeInterval?
    @ObservationIgnored private var relaxTask: Task<Void, Never>?

    private let tiltSource: TiltSource
    private let uprightHold: Duration

    init(tiltSource: TiltSource, uprightHold: Duration = .seconds(2.5)) {
        self.tiltSource = tiltSource
        self.uprightHold = uprightHold
    }

    /// Follows phone tilt until the calling task is cancelled, then settles to neutral.
    func trackTilt() async {
        guard tiltSource.isAvailable else { return }
        for await sample in tiltSource.samples() {
            ingest(sample)
        }
        filter.reset()
        lastSampleTime = nil
        lean = 0
    }

    func ingest(_ sample: TiltSample) {
        // Cap the step so a gap in updates can't cause a jump.
        let dt = lastSampleTime.map { min(max(sample.timestamp - $0, 0), 0.1) } ?? 0
        lastSampleTime = sample.timestamp

        let smoothed = filter.update(roll: sample.roll, dt: dt)

        if pose == .slouched {
            tiltInfluence = min(1, tiltInfluence + dt / Self.tiltReturnDuration)
        } else {
            tiltInfluence = max(0, tiltInfluence - dt / Self.tiltYieldDuration)
        }

        let newLean = smoothed * tiltInfluence
        // Skip changes too small to see, to avoid needless view updates.
        if abs(newLean - lean) >= 0.01 || (newLean == 0 && lean != 0) {
            lean = newLean
        }
    }

    /// Sits the mascot up for a moment, then lets it slouch again. Tapping again extends the hold.
    func resetPosture() {
        resetCount += 1
        holdUprightThenFall()
    }

    /// Starts upright and falls into the hunch on its own, without a reset haptic.
    /// Used when Home appears, so the slump plays out in front of the person.
    func sitUpThenFall() {
        holdUprightThenFall()
    }

    private func holdUprightThenFall() {
        pose = .upright
        relaxTask?.cancel()
        relaxTask = Task { [uprightHold] in
            try? await Task.sleep(for: uprightHold)
            guard !Task.isCancelled else { return }
            pose = .slouched
        }
    }
}
