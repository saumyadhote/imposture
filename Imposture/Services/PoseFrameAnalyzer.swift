import AVFoundation
import Foundation
import Vision

/// Runs Vision body-pose detection on camera frames, at most once per interval, and passes
/// on only the joints a side-view assessment needs. Pixel buffers are never retained.
///
/// Called on the analysis queue by AVFoundation; the lock guards state shared with `begin`/`end`.
nonisolated final class PoseFrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var interval: TimeInterval = 1
    private var lastAnalysed: TimeInterval?

    func begin(interval: TimeInterval, continuation: AsyncStream<PoseFrame>.Continuation) {
        lock.withLock {
            self.continuation?.finish()
            self.continuation = continuation
            self.interval = interval
            lastAnalysed = nil
        }
    }

    func end() {
        lock.withLock {
            continuation = nil
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let target: AsyncStream<PoseFrame>.Continuation? = lock.withLock {
            guard let continuation else { return nil }
            if let lastAnalysed, time - lastAnalysed < interval { return nil }
            lastAnalysed = time
            return continuation
        }
        guard let target, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            target.yield(PoseFrame(timestamp: time, joints: nil))
            return
        }
        let joints = request.results?.first.map { Self.sideJoints(from: $0, width: width, height: height) }
        target.yield(PoseFrame(timestamp: time, joints: joints))
    }

    /// Picks the side of the body facing the camera (the one Vision is more sure of).
    private static func sideJoints(from observation: VNHumanBodyPoseObservation, width: Double, height: Double) -> SideViewJoints {
        let points = (try? observation.recognizedPoints(.all)) ?? [:]
        func point(_ name: VNHumanBodyPoseObservation.JointName) -> BodyPoint? {
            guard let p = points[name], p.confidence > 0 else { return nil }
            // Normalised, origin bottom-left; scaled to pixels so angles aren't distorted.
            return BodyPoint(x: Double(p.location.x) * width, y: Double(p.location.y) * height, confidence: Double(p.confidence))
        }
        let left = [point(.leftEar), point(.leftShoulder), point(.leftHip)]
        let right = [point(.rightEar), point(.rightShoulder), point(.rightHip)]
        func score(_ side: [BodyPoint?]) -> Double { side.compactMap { $0?.confidence }.reduce(0, +) }
        let side = score(left) >= score(right) ? left : right
        return SideViewJoints(nose: point(.nose), ear: side[0], shoulder: side[1], hip: side[2])
    }
}
