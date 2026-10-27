import AVFoundation
import Foundation

enum CameraAccess: Equatable {
    case notDetermined
    case authorized
    case denied
    /// No camera on this device, e.g. the Simulator.
    case unavailable
}

enum CameraError: LocalizedError {
    case unavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "The camera isn't available right now."
        case .captureFailed: "The photo couldn't be taken."
        }
    }
}

/// The camera used for posture assessments.
protocol CameraControlling: AnyObject {
    var access: CameraAccess { get }
    /// The live session for a preview layer, or nil when there's no real camera (tests, previews).
    var previewSession: AVCaptureSession? { get }
    var isUsingFrontCamera: Bool { get }
    func requestAccess() async -> Bool
    func start() async throws
    func stop()
    func switchCamera() async throws
    /// On-device pose estimates from live frames, about `interval` seconds apart, until the
    /// consuming task is cancelled. Frames are analysed and dropped: nothing is recorded.
    func poseFrames(interval: TimeInterval) -> AsyncStream<PoseFrame>
}

/// AVFoundation camera with Vision body-pose estimation. Starts on the front camera.
/// Video frames are never saved or uploaded; only joint positions leave the camera queue.
final class CameraService: CameraControlling {
    private let graph = CaptureGraph()
    private(set) var isUsingFrontCamera = true

    var previewSession: AVCaptureSession? { graph.session }

    var access: CameraAccess {
        guard CaptureGraph.device(front: true) != nil || CaptureGraph.device(front: false) != nil else {
            return .unavailable
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start() async throws {
        let front = isUsingFrontCamera
        try await graph.perform { graph in
            if !graph.isConfigured {
                try graph.configure(front: front)
            }
            if !graph.session.isRunning {
                graph.session.startRunning()
            }
        }
    }

    func stop() {
        graph.queue.async { [graph] in
            if graph.session.isRunning {
                graph.session.stopRunning()
            }
        }
    }

    func switchCamera() async throws {
        let front = !isUsingFrontCamera
        try await graph.perform { graph in
            graph.session.beginConfiguration()
            defer { graph.session.commitConfiguration() }
            try graph.useCamera(front: front)
            graph.orientConnection()
        }
        isUsingFrontCamera = front
    }

    func poseFrames(interval: TimeInterval) -> AsyncStream<PoseFrame> {
        AsyncStream(bufferingPolicy: .bufferingNewest(4)) { continuation in
            graph.analyzer.begin(interval: interval, continuation: continuation)
            continuation.onTermination = { [analyzer = graph.analyzer] _ in
                analyzer.end()
            }
        }
    }
}

/// Owns the capture graph. Only touched on `queue`, hence unchecked Sendable.
nonisolated private final class CaptureGraph: @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "imposture.camera")
    let analyzer = PoseFrameAnalyzer()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "imposture.pose", qos: .userInitiated)
    private var input: AVCaptureDeviceInput?
    private(set) var isConfigured = false

    static func device(front: Bool) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back)
    }

    /// Runs `work` on the camera queue and returns its result.
    func perform(_ work: @escaping @Sendable (CaptureGraph) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                continuation.resume(with: Result { try work(self) })
            }
        }
    }

    func configure(front: Bool) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        try useCamera(front: front)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(analyzer, queue: analysisQueue)
        guard session.canAddOutput(videoOutput) else { throw CameraError.unavailable }
        session.addOutput(videoOutput)
        orientConnection()
        isConfigured = true
    }

    func useCamera(front: Bool) throws {
        guard let device = Self.device(front: front) else { throw CameraError.unavailable }
        let newInput = try AVCaptureDeviceInput(device: device)
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else {
            // Put the old camera back so the session keeps working.
            if let input, session.canAddInput(input) {
                session.addInput(input)
            }
            throw CameraError.unavailable
        }
        session.addInput(newInput)
        input = newInput
    }

    /// Upright portrait frames, unmirrored, so pose coordinates match the real scene.
    func orientConnection() {
        guard let connection = videoOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }
}
