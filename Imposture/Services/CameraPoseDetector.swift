// Ported from the vyam onboarding (Team-5). Live camera only: when there is no camera,
// the detector says so instead of producing simulated poses.
//
// Combines Vision 2D body pose, Vision 3D body pose (during the capture burst only) and a
// CoreMotion tilt reading, and gates each capture on tilt, framing, distance, orientation
// and stillness.

import AVFoundation
import Vision
import CoreMotion
import SwiftUI
import Combine
import simd

nonisolated public enum ScanBarrierState: Equatable {
    case searching(message: String)
    case violated(message: String, isWarning: Bool)
    case holding(progress: Double, message: String)
    case burstCapturing(angle: ScanAngle, currentFrame: Int, totalFrames: Int, message: String)
    case captured(angle: ScanAngle, message: String)
    
    public var isHoldingOrCaptured: Bool {
        switch self {
        case .holding, .burstCapturing, .captured:
            return true
        default:
            return false
        }
    }
    
    public var message: String {
        switch self {
        case .searching(let msg): return msg
        case .violated(let msg, _): return msg
        case .holding(_, let msg): return msg
        case .burstCapturing(_, _, _, let msg): return msg
        case .captured(_, let msg): return msg
        }
    }
}

@MainActor
public final class CameraPoseDetector: NSObject, ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var currentLandmarks: PostureLandmarks = PostureLandmarks()
    @Published public var currentLandmarks3D: PostureLandmarks3D? = nil
    @Published public var barrierState: ScanBarrierState = .searching(message: "Stand in frame to begin")
    @Published public var holdProgress: Double = 0.0
    @Published public var burstCurrentFrame: Int = 0
    @Published public var burstTotalFrames: Int = 5
    @Published public var isPoseDetected: Bool = false
    @Published public var hasCameraPermission: Bool = false
    @Published public var hasHardwareCamera: Bool = false
    /// No usable camera (for example, the Simulator). The scan can't run.
    @Published public var isCameraUnavailable: Bool = false
    
    @Published public var isUsingFrontCamera: Bool = true
    
    // CoreMotion Device Gravity State
    @Published public var devicePitchDegrees: Double = 0.0
    @Published public var isDeviceTiltedExcessively: Bool = false
    private let motionManager = CMMotionManager()
    
    // Multi-angle captured store
    @Published public var multiAngleData = MultiAngleScanData()
    @Published public var currentScanAngle: ScanAngle = .front
    @Published public var isAutoCaptureTriggered: Bool = false
    
    // Capture objects are only touched on `videoQueue` after setup.
    nonisolated(unsafe) public let captureSession = AVCaptureSession()
    nonisolated(unsafe) private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.team5.videoProcessingQueue", qos: .userInitiated)
    private var isConfigured = false
    
    // Thread-safe target scan angle for video output thread
    public var targetScanAngle: ScanAngle = .front
    
    // Burst flag read from the video queue, guarded by a lock.
    nonisolated(unsafe) private var isBurstModeActive: Bool = false
    private nonisolated let burstFlagLock = NSLock()
    
    // Stability & Multi-frame burst state (Calm, deliberate clinical pacing)
    private var holdCounter: Double = 0.0
    private let standardHoldSeconds: Double = 2.40
    private let dorsalHoldSeconds: Double = 2.60
    private var lastFrameTime: Date = Date()
    private var previousNeckPoint: CGPoint?
    private var isTransitioningAngle = false
    
    // Debounce for momentary frame flickers
    private var consecutiveViolationFrames: Int = 0
    private let violationToleranceFrames: Int = 6
    
    // Burst frame collection (5 high-precision frames with 0.35s cadence)
    private var currentBurstFrames: [PostureLandmarks] = []
    private var currentBurst3D: PostureLandmarks3D?
    private var lastBurstCaptureTime: Date = Date()
    private let burstFrameInterval: Double = 0.35
    private let requiredBurstFramesCount: Int = 5
    private var isBursting: Bool = false
    
    public override init() {
        super.init()
    }
    
    public func checkPermissionAndStart() {
        #if targetEnvironment(simulator)
        markCameraUnavailable()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
            setupAndStartSession()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                hasCameraPermission = granted
                if granted {
                    setupAndStartSession()
                } else {
                    barrierState = .violated(message: "Camera permission is required for scan", isWarning: true)
                }
            }
        case .denied, .restricted:
            hasCameraPermission = false
            barrierState = .violated(message: "Camera permission is disabled in Settings", isWarning: true)
        @unknown default:
            break
        }
        #endif
    }
    
    private func setupAndStartSession() {
        guard !isConfigured else {
            startSession()
            return
        }
        
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
            if #available(iOS 17.0, *) {
                deviceTypes.append(.builtInUltraWideCamera)
            }
            
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .front
            )
            
            let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video)
            
            guard let videoDevice = device,
                  let input = try? AVCaptureDeviceInput(device: videoDevice) else {
                Task { @MainActor in self.markCameraUnavailable() }
                return
            }
            
            Task { @MainActor in self.hasHardwareCamera = true }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                ]
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                self.captureSession.addOutput(self.videoDataOutput)
                
                // Align video feed to portrait with front mirroring
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                    if connection.isVideoMirroringSupported && device?.position == .front {
                        connection.isVideoMirrored = true
                    }
                }
            }
            
            self.captureSession.commitConfiguration()
            
            Task { @MainActor in
                self.isConfigured = true
                self.startSession()
            }
        }
    }
    
    public func startSession() {
        startMotionUpdates()
        
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                Task { @MainActor in
                    self.isRunning = true
                    self.lastFrameTime = Date()
                }
            }
        }
    }
    
    public func stopSession() {
        stopMotionUpdates()
        
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor in self.isRunning = false }
            }
        }
    }
    
    // MARK: - Camera Switching
    public func switchCamera() {
        isUsingFrontCamera.toggle()
        let useFront = isUsingFrontCamera
        #if !targetEnvironment(simulator)
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            if let currentInput = self.captureSession.inputs.first as? AVCaptureDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            let position: AVCaptureDevice.Position = useFront ? .front : .back
            var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
            if #available(iOS 17.0, *) {
                deviceTypes.append(.builtInUltraWideCamera)
            }
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: position
            )
            
            if let newDevice = discovery.devices.first,
               let newInput = try? AVCaptureDeviceInput(device: newDevice),
               self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = (position == .front)
                    }
                }
            }
            
            self.captureSession.commitConfiguration()
        }
        #endif
    }
    
    // MARK: - CoreMotion Device Gravity Updates
    private func startMotionUpdates() {
        #if !targetEnvironment(simulator)
        if motionManager.isDeviceMotionAvailable && !motionManager.isDeviceMotionActive {
            motionManager.deviceMotionUpdateInterval = 0.10 // 10 Hz (negligible battery draw)
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                // Upright portrait: gravity.y ~= -1.0, gravity.z ~= 0.0
                let pitchRad = atan2(motion.gravity.z, -motion.gravity.y)
                let pitchDeg = pitchRad * (180.0 / .pi)
                self.devicePitchDegrees = pitchDeg
                self.isDeviceTiltedExcessively = abs(pitchDeg) > 12.0
            }
        }
        #endif
    }
    
    private func stopMotionUpdates() {
        #if !targetEnvironment(simulator)
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        #endif
    }
    
    public func setTargetAngle(_ angle: ScanAngle) {
        currentScanAngle = angle
        targetScanAngle = angle
        holdCounter = 0.0
        holdProgress = 0.0
        isBursting = false
        setBurstFlag(false)
        consecutiveViolationFrames = 0
        currentBurstFrames.removeAll()
        currentBurst3D = nil
        burstCurrentFrame = 0
        barrierState = .searching(message: "Stand in frame for \(angle.title)")
        isTransitioningAngle = false
    }

    private func markCameraUnavailable() {
        hasHardwareCamera = false
        isCameraUnavailable = true
        isRunning = false
        barrierState = .violated(message: "No camera available. The body scan needs an iPhone camera.", isWarning: true)
    }
    
    private nonisolated func setBurstFlag(_ active: Bool) {
        burstFlagLock.lock()
        isBurstModeActive = active
        burstFlagLock.unlock()
    }
    
    private nonisolated func getBurstFlag() -> Bool {
        burstFlagLock.lock()
        defer { burstFlagLock.unlock() }
        return isBurstModeActive
    }
    
    // MARK: - Barrier Evaluation & State Machine (Main Actor)
    private func processLandmarksFrame(_ landmarks: PostureLandmarks, landmarks3D: PostureLandmarks3D? = nil) {
        guard !isTransitioningAngle else { return }
        
        let now = Date()
        let dt = min(0.1, max(0.016, now.timeIntervalSince(lastFrameTime)))
        lastFrameTime = now
        
        // Barrier 0: Device Tilt Gate (CoreMotion)
        if isDeviceTiltedExcessively {
            registerViolation(message: "Tilt phone more upright", isWarning: true)
            return
        }
        
        // Barrier 1: Detection confidence & upper body presence
        guard landmarks.hasUpperBody else {
            isPoseDetected = false
            registerViolation(message: "Stand where your head and shoulders are visible")
            return
        }
        
        isPoseDetected = true
        self.currentLandmarks = landmarks
        
        // Barrier 2: Distance / Proximity Checks
        if let span = landmarks.shoulderWidth {
            if span > 0.68 {
                registerViolation(message: "Step back — you are too close", isWarning: true)
                return
            } else if span < 0.12 && currentScanAngle == .front {
                registerViolation(message: "Step closer to the camera", isWarning: true)
                return
            }
        }
        
        // Barrier 3: Head boundary vertical framing
        if let nose = landmarks.nose, nose.y > 0.95 {
            registerViolation(message: "Head cut off — tilt camera up or step back", isWarning: true)
            return
        }
        if let neck = landmarks.neck, neck.y < 0.28 {
            registerViolation(message: "Too low in frame — raise phone to chest level", isWarning: true)
            return
        }
        
        // Barrier 4: STRICT ANATOMICAL ORIENTATION CHECK
        switch ClinicalPostureAnalyzer.validateOrientation(landmarks: landmarks, for: currentScanAngle) {
        case .valid:
            break
        case .violation(let message):
            registerViolation(message: message, isWarning: false)
            return
        }
        
        // Barrier 5: Strict Stability & Micro-Jitter Check
        if let neck = landmarks.neck, let prev = previousNeckPoint {
            let movement = hypot(neck.x - prev.x, neck.y - prev.y)
            if movement > 0.040 {
                registerViolation(message: "Hold still — scanning", isWarning: false)
                previousNeckPoint = neck
                return
            }
        }
        previousNeckPoint = landmarks.neck
        
        // ALL BARRIERS PASSED -> Reset violation debouncer and proceed with Stillness Hold
        consecutiveViolationFrames = 0
        let requiredSeconds = (currentScanAngle == .back) ? dorsalHoldSeconds : standardHoldSeconds
        
        if !isBursting {
            holdCounter += dt
            holdProgress = min(1.0, holdCounter / requiredSeconds)
            
            let secondsRemaining = max(1, Int(ceil((1.0 - holdProgress) * requiredSeconds)))
            if holdProgress < 1.0 {
                barrierState = .holding(
                    progress: holdProgress,
                    message: (currentScanAngle == .back) ? "Hold steady (\(secondsRemaining)s)..." : "Hold still (\(secondsRemaining)s)..."
                )
            } else {
                // Stillness confirmed -> Begin 5-frame burst capture (and activate 3D request)
                isBursting = true
                setBurstFlag(true)
                currentBurstFrames.removeAll()
                currentBurst3D = nil
                lastBurstCaptureTime = Date.distantPast
            }
        }
        
        // EXECUTE MULTI-FRAME BURST (5 frames per angle)
        if isBursting {
            let burstElapsed = now.timeIntervalSince(lastBurstCaptureTime)
            if burstElapsed >= burstFrameInterval {
                lastBurstCaptureTime = now
                currentBurstFrames.append(landmarks)
                if let l3d = landmarks3D, currentBurst3D == nil {
                    currentBurst3D = l3d
                }
                burstCurrentFrame = currentBurstFrames.count
                
                // Light shutter haptic feedback per burst frame
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                barrierState = .burstCapturing(
                    angle: currentScanAngle,
                    currentFrame: burstCurrentFrame,
                    totalFrames: requiredBurstFramesCount,
                    message: "Capturing frame \(burstCurrentFrame) of \(requiredBurstFramesCount)..."
                )
                
                // Burst Complete (5 frames captured)
                if currentBurstFrames.count >= requiredBurstFramesCount {
                    completeAngleBurstCapture()
                }
            }
        }
    }
    
    // MARK: - Debounced Violation Registration
    private func registerViolation(message: String, isWarning: Bool = false) {
        consecutiveViolationFrames += 1
        if consecutiveViolationFrames >= violationToleranceFrames {
            resetHoldState(message: message, isWarning: isWarning)
        } else {
            barrierState = .violated(message: message, isWarning: isWarning)
        }
    }
    
    private func resetHoldState(message: String, isWarning: Bool = false) {
        holdCounter = 0.0
        holdProgress = 0.0
        isBursting = false
        setBurstFlag(false)
        currentBurstFrames.removeAll()
        currentBurst3D = nil
        burstCurrentFrame = 0
        barrierState = .violated(message: message, isWarning: isWarning)
    }
    
    private func completeAngleBurstCapture() {
        isTransitioningAngle = true
        isBursting = false
        setBurstFlag(false)
        
        // Compute statistical median landmarks across all 5 frames for sub-pixel precision
        let medianLandmarks = ClinicalPostureAnalyzer.aggregateLandmarks(currentBurstFrames) ?? currentLandmarks
        
        // Store multi-frame burst and median aggregate into MultiAngleScanData
        switch currentScanAngle {
        case .front:
            multiAngleData.frontFrames = currentBurstFrames
            multiAngleData.front = medianLandmarks
            multiAngleData.front3D = currentBurst3D
        case .right:
            multiAngleData.rightFrames = currentBurstFrames
            multiAngleData.right = medianLandmarks
            multiAngleData.right3D = currentBurst3D
        case .left:
            multiAngleData.leftFrames = currentBurstFrames
            multiAngleData.left = medianLandmarks
            multiAngleData.left3D = currentBurst3D
        case .back:
            multiAngleData.backFrames = currentBurstFrames
            multiAngleData.back = medianLandmarks
            multiAngleData.back3D = currentBurst3D
        }
        
        multiAngleData.devicePitchDegrees = devicePitchDegrees
        
        // Success Haptic Feedback (Heavy + Success Notification)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        barrierState = .captured(
            angle: currentScanAngle,
            message: "\(currentScanAngle.title) Verified (5 frames) ✓"
        )
        isAutoCaptureTriggered = true
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Vision Pose Tracking)
extension CameraPoseDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request2D = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([request2D])
            guard let observation = request2D.results?.first else {
                Task { @MainActor [weak self] in
                    self?.processLandmarksFrame(PostureLandmarks(confidence: 0.0))
                }
                return
            }
            
            func getPoint(_ joint: VNHumanBodyPoseObservation.JointName, minConfidence: Float = 0.35) -> CGPoint? {
                guard let recognized = try? observation.recognizedPoint(joint),
                      recognized.confidence >= minConfidence else { return nil }
                return CGPoint(x: recognized.location.x, y: recognized.location.y)
            }
            
            let nose = getPoint(.nose, minConfidence: 0.30)
            let leftEye = getPoint(.leftEye, minConfidence: 0.30)
            let rightEye = getPoint(.rightEye, minConfidence: 0.30)
            let neck = getPoint(.neck, minConfidence: 0.30)
            let leftEar = getPoint(.leftEar, minConfidence: 0.30)
            let rightEar = getPoint(.rightEar, minConfidence: 0.30)
            let leftShoulder = getPoint(.leftShoulder, minConfidence: 0.30)
            let rightShoulder = getPoint(.rightShoulder, minConfidence: 0.30)
            let leftHip = getPoint(.leftHip, minConfidence: 0.30)
            let rightHip = getPoint(.rightHip, minConfidence: 0.30)
            
            let landmarks = PostureLandmarks(
                nose: nose,
                neck: neck,
                leftEye: leftEye,
                rightEye: rightEye,
                leftEar: leftEar,
                rightEar: rightEar,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftHip: leftHip,
                rightHip: rightHip,
                confidence: 0.90
            )
            
            // Execute high-precision 3D metric inference ONLY during active burst capture
            var landmarks3D: PostureLandmarks3D? = nil
            if self.getBurstFlag() {
                let request3D = VNDetectHumanBodyPose3DRequest()
                try? handler.perform([request3D])
                if let obs3D = request3D.results?.first {
                    func get3DPoint(_ joint: VNHumanBodyPose3DObservation.JointName) -> SIMD3<Float>? {
                        guard obs3D.confidence >= 0.30, let pt = try? obs3D.recognizedPoint(joint) else { return nil }
                        let pos = pt.position.columns.3
                        return SIMD3<Float>(pos.x, pos.y, pos.z)
                    }
                    
                    let head = get3DPoint(.centerHead)
                    let shoulder = get3DPoint(.centerShoulder)
                    if head != nil || shoulder != nil {
                        landmarks3D = PostureLandmarks3D(
                            centerHead: head,
                            centerShoulder: shoulder,
                            spine: get3DPoint(.spine),
                            root: get3DPoint(.root),
                            leftShoulder: get3DPoint(.leftShoulder),
                            rightShoulder: get3DPoint(.rightShoulder),
                            confidence: Double(obs3D.confidence)
                        )
                    }
                }
            }
            
            Task { @MainActor [weak self] in
                self?.processLandmarksFrame(landmarks, landmarks3D: landmarks3D)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.processLandmarksFrame(PostureLandmarks(confidence: 0.0))
            }
        }
    }
}
