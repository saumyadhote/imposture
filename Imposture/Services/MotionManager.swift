import CoreMotion
import Foundation

/// One reading of how far the phone is tilted side to side.
struct TiltSample: Sendable, Equatable {
    /// Degrees from level. Positive means the right edge is lower. Works whether
    /// the phone is held upright or lying flat, and ignores tilting toward or away.
    var roll: Double
    /// Seconds on the motion clock, used to measure time between samples.
    var timestamp: TimeInterval
}

/// A live feed of phone tilt.
protocol TiltSource {
    var isAvailable: Bool { get }
    /// Samples until the consuming task is cancelled. Finishes immediately when unavailable.
    func samples() -> AsyncStream<TiltSample>
}

/// Core Motion device-motion updates as an async stream.
///
/// Sensors run only while a stream is being consumed: cancelling the consuming
/// task (for example when a `.task` view disappears) stops updates.
final class MotionManager: TiltSource {
    private static let updateInterval = 1.0 / 60.0

    /// Created on first use, since a view may construct this more than once.
    private lazy var manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "gogo.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    /// Identifies the current stream so a stale one can't stop a newer one.
    private var generation = 0

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func samples() -> AsyncStream<TiltSample> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            guard isAvailable else {
                continuation.finish()
                return
            }
            generation += 1
            let current = generation
            manager.deviceMotionUpdateInterval = Self.updateInterval
            manager.startDeviceMotionUpdates(to: queue, withHandler: Self.handler(yieldingTo: continuation))
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.stop(generation: current) }
            }
        }
    }

    private func stop(generation finished: Int) {
        guard finished == generation else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Runs on the motion queue, so it must not touch main-actor state.
    nonisolated private static func handler(
        yieldingTo continuation: AsyncStream<TiltSample>.Continuation
    ) -> CMDeviceMotionHandler {
        { motion, _ in
            guard let motion else { return }
            // Gravity comes from the fused attitude estimate, so it is far steadier
            // than raw accelerometer data. Its x component is the side-to-side tilt.
            let x = min(max(motion.gravity.x, -1), 1)
            continuation.yield(TiltSample(roll: asin(x) * 180 / .pi, timestamp: motion.timestamp))
        }
    }
}
