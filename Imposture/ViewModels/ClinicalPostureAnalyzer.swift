// Ported from the vyam onboarding (Team-5).
//
// Turns the body-scan landmarks into posture estimates: craniovertebral angle from a side
// view, shoulder tilt from the front, a plumb-line offset from the back, and forward head
// translation and upper-back curve from Vision's 3D pose. Every value is an estimate from a
// phone camera, not a clinical measurement, and each one is reported only when the views it
// needs were actually captured. Nothing is filled in from defaults or from focus choices.

import Foundation
import CoreGraphics
import simd

// MARK: - Clinical Normative Standards
nonisolated public enum ClinicalNorms {
    /// Craniovertebral Angle (CVA): Tragus-to-C7 angle relative to horizontal.
    /// Healthy range: 50.0° - 55.0°+.
    public static let optimalCVA: Double = 52.0
    public static let mildTechNeckThreshold: Double = 49.0
    public static let moderateTechNeckThreshold: Double = 44.0
    
    /// Cervical Sagittal Vertical Axis (SVA) in millimeters (3D metric anterior translation)
    /// Healthy / Optimal: < 25 mm
    /// Mild forward translation: 25 mm - 40 mm
    /// Significant forward translation: > 40 mm
    public static let optimalCervicalSVAMillimeters: Double = 25.0
    public static let mildCervicalSVAMillimeters: Double = 40.0
    
    /// Thoracic Kyphosis Curvature Deviation Angle (degrees)
    /// Healthy / Normal: < 20.0°
    /// Kyphotic curvature: > 25.0°
    public static let optimalThoracicKyphosisAngle: Double = 20.0
    public static let noticeableThoracicKyphosisAngle: Double = 25.0
    
    /// Shoulder Symmetry: Absolute angular tilt between left and right acromion.
    /// Healthy: < 2.5°.
    public static let optimalShoulderTilt: Double = 2.5
    public static let noticeableShoulderTilt: Double = 4.0
    
    /// Dorsal Plumb Line: Max lateral offset between neck and mid-pelvis in coronal plane
    public static let optimalPlumbOffsetPercent: Double = 2.0
    
    /// Baseline human head weight in neutral alignment (lbs)
    public static let averageHeadWeightLbs: Double = 11.0
    
    /// Effective load factor per degree of forward head posture loss
    /// (Based on Dr. Kenneth Hansraj cervical spine biomechanical studies)
    public static func estimatedCervicalLoadLbs(forCVA angle: Double) -> Double {
        let loss = max(0, optimalCVA - angle)
        // Each degree lost contributes ~0.9 - 1.2 lbs of extra mechanical leverage
        return averageHeadWeightLbs + (loss * 1.15)
    }
}

// MARK: - Metric Justification Model
nonisolated public struct ClinicalMetric: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let measuredValue: String
    public let normativeRange: String
    public let status: MetricStatus
    public let justification: String
    
    public enum MetricStatus: String, Equatable, Hashable, Sendable {
        case optimal = "Within guide"
        case attention = "Worth working on"
        case severe = "Further from guide"
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        measuredValue: String,
        normativeRange: String,
        status: MetricStatus,
        justification: String
    ) {
        self.id = id
        self.name = name
        self.measuredValue = measuredValue
        self.normativeRange = normativeRange
        self.status = status
        self.justification = justification
    }
}

// MARK: - Raw 2D Landmark Points (Normalized 0.0 - 1.0)
nonisolated public struct PostureLandmarks: Equatable, Sendable {
    public let nose: CGPoint?
    public let neck: CGPoint?
    public let leftEye: CGPoint?
    public let rightEye: CGPoint?
    public let leftEar: CGPoint?
    public let rightEar: CGPoint?
    public let leftShoulder: CGPoint?
    public let rightShoulder: CGPoint?
    public let leftHip: CGPoint?
    public let rightHip: CGPoint?
    public let confidence: Double
    
    public init(
        nose: CGPoint? = nil,
        neck: CGPoint? = nil,
        leftEye: CGPoint? = nil,
        rightEye: CGPoint? = nil,
        leftEar: CGPoint? = nil,
        rightEar: CGPoint? = nil,
        leftShoulder: CGPoint? = nil,
        rightShoulder: CGPoint? = nil,
        leftHip: CGPoint? = nil,
        rightHip: CGPoint? = nil,
        confidence: Double = 1.0
    ) {
        self.nose = nose
        self.neck = neck
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.leftHip = leftHip
        self.rightHip = rightHip
        self.confidence = confidence
    }
    
    public var hasUpperBody: Bool {
        return (leftShoulder != nil || rightShoulder != nil || neck != nil) && confidence >= 0.35
    }
    
    public var shoulderWidth: Double? {
        guard let left = leftShoulder, let right = rightShoulder else { return nil }
        return Double(abs(left.x - right.x))
    }
}

// MARK: - Metric 3D Landmark Points (Meters relative to camera origin)
nonisolated public struct PostureLandmarks3D: Equatable, Sendable {
    public let centerHead: SIMD3<Float>?
    public let centerShoulder: SIMD3<Float>?
    public let spine: SIMD3<Float>?
    public let root: SIMD3<Float>?
    public let leftShoulder: SIMD3<Float>?
    public let rightShoulder: SIMD3<Float>?
    public let confidence: Double
    
    public init(
        centerHead: SIMD3<Float>? = nil,
        centerShoulder: SIMD3<Float>? = nil,
        spine: SIMD3<Float>? = nil,
        root: SIMD3<Float>? = nil,
        leftShoulder: SIMD3<Float>? = nil,
        rightShoulder: SIMD3<Float>? = nil,
        confidence: Double = 1.0
    ) {
        self.centerHead = centerHead
        self.centerShoulder = centerShoulder
        self.spine = spine
        self.root = root
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.confidence = confidence
    }
    
    public var hasMetricSpine: Bool {
        return (centerHead != nil && centerShoulder != nil) && confidence >= 0.35
    }
}

// MARK: - Multi-Angle Scan Data Container (Dual 2D + 3D with 5 Frames per Angle Burst)
nonisolated public struct MultiAngleScanData: Equatable, Sendable {
    public var front: PostureLandmarks?
    public var left: PostureLandmarks?
    public var right: PostureLandmarks?
    public var back: PostureLandmarks?
    
    // Multi-frame bursts (5 frames captured per face/angle)
    public var frontFrames: [PostureLandmarks]
    public var leftFrames: [PostureLandmarks]
    public var rightFrames: [PostureLandmarks]
    public var backFrames: [PostureLandmarks]
    
    // 3D Spatial Metric Landmarks (Captured during steady burst)
    public var front3D: PostureLandmarks3D?
    public var left3D: PostureLandmarks3D?
    public var right3D: PostureLandmarks3D?
    public var back3D: PostureLandmarks3D?
    
    // CoreMotion Calibrated Device Pitch (tilt relative to true vertical gravity)
    public var devicePitchDegrees: Double?
    
    public var isScanCompleted: Bool
    
    public init(
        front: PostureLandmarks? = nil,
        left: PostureLandmarks? = nil,
        right: PostureLandmarks? = nil,
        back: PostureLandmarks? = nil,
        frontFrames: [PostureLandmarks] = [],
        leftFrames: [PostureLandmarks] = [],
        rightFrames: [PostureLandmarks] = [],
        backFrames: [PostureLandmarks] = [],
        front3D: PostureLandmarks3D? = nil,
        left3D: PostureLandmarks3D? = nil,
        right3D: PostureLandmarks3D? = nil,
        back3D: PostureLandmarks3D? = nil,
        devicePitchDegrees: Double? = nil,
        isScanCompleted: Bool = false
    ) {
        self.front = front
        self.left = left
        self.right = right
        self.back = back
        self.frontFrames = frontFrames
        self.leftFrames = leftFrames
        self.rightFrames = rightFrames
        self.backFrames = backFrames
        self.front3D = front3D
        self.left3D = left3D
        self.right3D = right3D
        self.back3D = back3D
        self.devicePitchDegrees = devicePitchDegrees
        self.isScanCompleted = isScanCompleted
    }
    
    public var totalFramesCount: Int {
        return frontFrames.count + leftFrames.count + rightFrames.count + backFrames.count
    }
    
    public var hasMinimumClinicalData: Bool {
        let hasFront = front != nil || !frontFrames.isEmpty
        let hasSide = left != nil || !leftFrames.isEmpty || right != nil || !rightFrames.isEmpty
        return hasFront && hasSide
    }
    
    public var has3DData: Bool {
        return (left3D?.hasMetricSpine == true) || (right3D?.hasMetricSpine == true) || (front3D?.hasMetricSpine == true)
    }
}

// MARK: - Analysis Result
nonisolated public struct ClinicalScanAnalysis: Equatable, Sendable {
    public let cvaAngle: Double?
    public let shoulderTiltAngle: Double?
    public let estimatedNeckLoadLbs: Double?
    public let cervicalSVAMillimeters: Double?
    public let thoracicKyphosisAngle: Double?
    public let metrics: [ClinicalMetric]
    public let findings: [PostureFinding]
    public let isClinicallyMeasured: Bool
    public let totalCalibratedFrames: Int
    
    public init(
        cvaAngle: Double?,
        shoulderTiltAngle: Double?,
        estimatedNeckLoadLbs: Double?,
        cervicalSVAMillimeters: Double? = nil,
        thoracicKyphosisAngle: Double? = nil,
        metrics: [ClinicalMetric],
        findings: [PostureFinding],
        isClinicallyMeasured: Bool = true,
        totalCalibratedFrames: Int = 0
    ) {
        self.cvaAngle = cvaAngle
        self.shoulderTiltAngle = shoulderTiltAngle
        self.estimatedNeckLoadLbs = estimatedNeckLoadLbs
        self.cervicalSVAMillimeters = cervicalSVAMillimeters
        self.thoracicKyphosisAngle = thoracicKyphosisAngle
        self.metrics = metrics
        self.findings = findings
        self.isClinicallyMeasured = isClinicallyMeasured
        self.totalCalibratedFrames = totalCalibratedFrames
    }
}

// MARK: - Pure Math Biomechanical Analyzer (2D + 3D + CoreMotion)
nonisolated public struct ClinicalPostureAnalyzer: Sendable {
    
    /// Computes Craniovertebral Angle (CVA) in degrees from Ear and Neck landmarks,
    /// with optional CoreMotion gravity tilt compensation.
    public static func computeCVA(
        ear: CGPoint,
        neck: CGPoint,
        devicePitchDegrees: Double? = nil
    ) -> Double {
        let dx = max(0.001, abs(ear.x - neck.x))
        let dy = max(0.001, abs(ear.y - neck.y))
        // In Vision coordinate system, Y increases upwards
        let radians = atan2(dy, dx)
        var degrees = radians * (180.0 / .pi)
        
        // Gravity plumb-line compensation:
        // If the phone is tilted slightly backward (within operational bounds ±12°),
        // adjust the measured angle to true gravitational horizontal.
        if let pitch = devicePitchDegrees, abs(pitch) <= 12.0 {
            degrees += (pitch * 0.50) // Proportional affine gravity correction factor
        }
        
        return min(85.0, max(20.0, degrees))
    }
    
    /// Computes Craniovertebral Angle (CVA) in degrees from an anterolateral side-view (40-50° desk angle).
    /// Uses projective trigonometry to calibrate sagittal depth:
    /// deltaZ_true = deltaX_proj / sin(deskAngle), maintaining full equivalence with Feature 1 clinical norms.
    public static func computeObliqueDeskCVA(
        ear: CGPoint,
        neck: CGPoint,
        deskAngleDegrees: Double = 45.0,
        devicePitchDegrees: Double? = nil
    ) -> Double {
        let dxProj = max(0.001, abs(ear.x - neck.x))
        let dy = max(0.001, abs(ear.y - neck.y))
        
        let angleClamped = min(50.0, max(40.0, deskAngleDegrees))
        let sinAngle = sin(angleClamped * .pi / 180.0)
        let dxSagittal = dxProj / sinAngle
        
        let radians = atan2(dy, dxSagittal)
        var degrees = radians * (180.0 / .pi)
        
        if let pitch = devicePitchDegrees, abs(pitch) <= 12.0 {
            degrees += (pitch * 0.50)
        }
        
        return min(85.0, max(20.0, degrees))
    }
    
    /// Overload taking PostureLandmarks for desk posture monitoring at 40-50° side angle
    public static func computeObliqueDeskCVA(
        landmarks: PostureLandmarks,
        deskAngleDegrees: Double = 45.0,
        devicePitchDegrees: Double? = nil
    ) -> Double? {
        guard let neck = landmarks.neck else { return nil }
        
        let primaryEar: CGPoint? = {
            if let r = landmarks.rightEar, let l = landmarks.leftEar {
                return abs(r.x - neck.x) >= abs(l.x - neck.x) ? r : l
            }
            return landmarks.rightEar ?? landmarks.leftEar
        }()
        
        if let ear = primaryEar {
            return computeObliqueDeskCVA(
                ear: ear,
                neck: neck,
                deskAngleDegrees: deskAngleDegrees,
                devicePitchDegrees: devicePitchDegrees
            )
        } else if let nose = landmarks.nose {
            let effectiveNose = CGPoint(
                x: neck.x + (nose.x - neck.x) * 0.70,
                y: nose.y
            )
            return computeObliqueDeskCVA(
                ear: effectiveNose,
                neck: neck,
                deskAngleDegrees: deskAngleDegrees,
                devicePitchDegrees: devicePitchDegrees
            )
        }
        return nil
    }
    
    /// Computes shoulder symmetry tilt in degrees from landmarks
    public static func computeShoulderTilt(landmarks: PostureLandmarks) -> Double? {
        guard let left = landmarks.leftShoulder, let right = landmarks.rightShoulder else { return nil }
        return computeShoulderTilt(left: left, right: right)
    }
    
    /// Computes 3D metric Sagittal Vertical Axis (SVA) in millimeters from head center to C7 shoulder
    public static func compute3DCervicalSVA(head: SIMD3<Float>, shoulder: SIMD3<Float>) -> Double {
        // In Vision 3D camera coordinate space, Z axis represents depth (anterior-posterior displacement)
        let deltaZ = Double(abs(head.z - shoulder.z))
        return deltaZ * 1000.0 // Convert meters to millimeters
    }
    
    /// Computes 3D Thoracic Kyphosis Curvature Angle from Pelvis (root) -> Mid-Spine -> Upper-Shoulder (C7)
    public static func computeThoracicKyphosisAngle(root: SIMD3<Float>, spine: SIMD3<Float>, shoulder: SIMD3<Float>) -> Double {
        let lowerSpineVector = spine - root
        let upperSpineVector = shoulder - spine
        
        let len1 = simd_length(lowerSpineVector)
        let len2 = simd_length(upperSpineVector)
        guard len1 > 0.001, len2 > 0.001 else { return 0.0 }
        
        let v1 = lowerSpineVector / len1
        let v2 = upperSpineVector / len2
        let dot = max(-1.0, min(1.0, simd_dot(v1, v2)))
        let radians = acos(dot)
        return Double(radians) * (180.0 / .pi)
    }
    
    /// Computes shoulder symmetry tilt in degrees between left and right shoulders
    public static func computeShoulderTilt(left: CGPoint, right: CGPoint) -> Double {
        let dy = abs(left.y - right.y)
        let dx = max(0.001, abs(left.x - right.x))
        let radians = atan2(dy, dx)
        return radians * (180.0 / .pi)
    }
    
    /// Statistical Median Fusion across a burst of 5 frames to eliminate sensor jitter and micro-tremors
    public static func aggregateLandmarks(_ frames: [PostureLandmarks]) -> PostureLandmarks? {
        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0] }
        
        func medianPoint(_ points: [CGPoint?]) -> CGPoint? {
            let valid = points.compactMap { $0 }
            guard !valid.isEmpty else { return nil }
            let sortedX = valid.map { $0.x }.sorted()
            let sortedY = valid.map { $0.y }.sorted()
            let mid = sortedX.count / 2
            let medX = sortedX.count % 2 == 1 ? sortedX[mid] : (sortedX[mid - 1] + sortedX[mid]) / 2.0
            let medY = sortedY.count % 2 == 1 ? sortedY[mid] : (sortedY[mid - 1] + sortedY[mid]) / 2.0
            return CGPoint(x: medX, y: medY)
        }
        
        let avgConf = frames.map { $0.confidence }.reduce(0.0, +) / Double(frames.count)
        
        return PostureLandmarks(
            nose: medianPoint(frames.map { $0.nose }),
            neck: medianPoint(frames.map { $0.neck }),
            leftEye: medianPoint(frames.map { $0.leftEye }),
            rightEye: medianPoint(frames.map { $0.rightEye }),
            leftEar: medianPoint(frames.map { $0.leftEar }),
            rightEar: medianPoint(frames.map { $0.rightEar }),
            leftShoulder: medianPoint(frames.map { $0.leftShoulder }),
            rightShoulder: medianPoint(frames.map { $0.rightShoulder }),
            leftHip: medianPoint(frames.map { $0.leftHip }),
            rightHip: medianPoint(frames.map { $0.rightHip }),
            confidence: avgConf
        )
    }
    
    /// Analyses the captured views. A metric or finding appears only when its views were captured.
    public static func analyzeScan(scanData: MultiAngleScanData, userFocus: Set<FocusArea> = []) -> ClinicalScanAnalysis {
        var metrics: [ClinicalMetric] = []
        var findings: [PostureFinding] = []

        let resolvedFront = scanData.front ?? aggregateLandmarks(scanData.frontFrames)
        let resolvedLeft = scanData.left ?? aggregateLandmarks(scanData.leftFrames)
        let resolvedRight = scanData.right ?? aggregateLandmarks(scanData.rightFrames)
        let resolvedBack = scanData.back ?? aggregateLandmarks(scanData.backFrames)

        // 1. Craniovertebral angle, from whichever side views were captured.
        func sideCVA(_ view: PostureLandmarks?, ear: (PostureLandmarks) -> CGPoint?, shoulder: (PostureLandmarks) -> CGPoint?) -> Double? {
            guard let view, let earPoint = ear(view) ?? view.nose, let neckPoint = view.neck ?? shoulder(view) else { return nil }
            return computeCVA(ear: earPoint, neck: neckPoint, devicePitchDegrees: scanData.devicePitchDegrees)
        }
        let leftCVA = sideCVA(resolvedLeft, ear: \.leftEar, shoulder: \.leftShoulder)
        let rightCVA = sideCVA(resolvedRight, ear: \.rightEar, shoulder: \.rightShoulder)
        let sides = [leftCVA, rightCVA].compactMap { $0 }
        let measuredCVA: Double? = sides.isEmpty ? nil : sides.reduce(0, +) / Double(sides.count)

        var neckLoad: Double?
        if let cva = measuredCVA {
            let load = ClinicalNorms.estimatedCervicalLoadLbs(forCVA: cva)
            neckLoad = load
            let status: ClinicalMetric.MetricStatus = cva >= ClinicalNorms.optimalCVA
                ? .optimal
                : (cva >= ClinicalNorms.moderateTechNeckThreshold ? .attention : .severe)
            metrics.append(ClinicalMetric(
                name: "Neck angle (CVA)",
                measuredValue: String(format: "%.1f°", cva),
                normativeRange: "≥ 52°",
                status: status,
                justification: sides.count == 2
                    ? "Average of your left and right side views, corrected for phone tilt."
                    : "From your side view, corrected for phone tilt."
            ))
            if status != .optimal {
                findings.append(PostureFinding(
                    title: "Tech neck",
                    detail: String(format: "Your head sits forward of your shoulders (%.0f° neck angle).", cva),
                    severity: status == .severe ? .significant : .moderate
                ))
            }
            metrics.append(ClinicalMetric(
                name: "Estimated head load",
                measuredValue: "\(Int(load.rounded())) lb",
                normativeRange: "About 10–12 lb upright",
                status: load > 18 ? .attention : .optimal,
                justification: "A rough model of how much a forward head adds to the load on your neck."
            ))
        }

        // 2. 3D estimates from Vision's body pose, when a side view captured them.
        var measuredSVA: Double?
        var measuredTK: Double?
        if let profile = scanData.right3D ?? scanData.left3D, profile.hasMetricSpine,
           let head = profile.centerHead, let shoulder = profile.centerShoulder {
            let sva = compute3DCervicalSVA(head: head, shoulder: shoulder)
            measuredSVA = sva
            metrics.append(ClinicalMetric(
                name: "Forward head shift",
                measuredValue: String(format: "%.0f mm", sva),
                normativeRange: "< 25 mm",
                status: sva <= ClinicalNorms.optimalCervicalSVAMillimeters ? .optimal : (sva <= ClinicalNorms.mildCervicalSVAMillimeters ? .attention : .severe),
                justification: "Estimated from Vision's 3D body pose; treat it as a guide."
            ))
            if let root = profile.root, let spine = profile.spine {
                let tk = computeThoracicKyphosisAngle(root: root, spine: spine, shoulder: shoulder)
                measuredTK = tk
                let status: ClinicalMetric.MetricStatus = tk <= ClinicalNorms.optimalThoracicKyphosisAngle
                    ? .optimal
                    : (tk <= ClinicalNorms.noticeableThoracicKyphosisAngle ? .attention : .severe)
                metrics.append(ClinicalMetric(
                    name: "Upper-back curve",
                    measuredValue: String(format: "%.0f°", tk),
                    normativeRange: "< 20°",
                    status: status,
                    justification: "Estimated from Vision's 3D body pose; treat it as a guide."
                ))
                if status != .optimal {
                    findings.append(PostureFinding(
                        title: "Rounded upper back",
                        detail: String(format: "Your upper back curves more than the guide (%.0f°).", tk),
                        severity: status == .severe ? .significant : .moderate
                    ))
                }
            }
        }

        // 3. Shoulder level, from the front view.
        var measuredTilt: Double?
        if let front = resolvedFront, let left = front.leftShoulder, let right = front.rightShoulder {
            let tilt = computeShoulderTilt(left: left, right: right)
            measuredTilt = tilt
            let status: ClinicalMetric.MetricStatus = tilt <= ClinicalNorms.optimalShoulderTilt ? .optimal : .attention
            metrics.append(ClinicalMetric(
                name: "Shoulder level",
                measuredValue: String(format: "%.1f° tilt", tilt),
                normativeRange: "< 2.5°",
                status: status,
                justification: "Difference in height between your shoulders, from the front view."
            ))
            if status != .optimal {
                findings.append(PostureFinding(
                    title: "Uneven shoulders",
                    detail: String(format: "One shoulder sits higher than the other (%.1f°).", tilt),
                    severity: tilt > ClinicalNorms.noticeableShoulderTilt ? .significant : .moderate
                ))
            }
        }

        // 4. Plumb line, from the back view with both hips visible.
        if let back = resolvedBack, let neck = back.neck, let lh = back.leftHip, let rh = back.rightHip {
            let offset = Double(abs(neck.x - (lh.x + rh.x) / 2)) * 100
            metrics.append(ClinicalMetric(
                name: "Side-to-side balance",
                measuredValue: String(format: "%.1f%% offset", offset),
                normativeRange: "< 2%",
                status: offset <= ClinicalNorms.optimalPlumbOffsetPercent ? .optimal : .attention,
                justification: "How far your neck sits from the middle of your hips, from the back view."
            ))
        }

        let frames = scanData.totalFramesCount
        return ClinicalScanAnalysis(
            cvaAngle: measuredCVA,
            shoulderTiltAngle: measuredTilt,
            estimatedNeckLoadLbs: neckLoad,
            cervicalSVAMillimeters: measuredSVA,
            thoracicKyphosisAngle: measuredTK,
            metrics: metrics,
            findings: findings,
            isClinicallyMeasured: !metrics.isEmpty,
            totalCalibratedFrames: frames
        )
    }
}

// MARK: - Strict Anatomical Orientation Validator
nonisolated public enum PoseOrientationValidationResult: Equatable, Sendable {
    case valid
    case violation(message: String)
}

extension ClinicalPostureAnalyzer {
    public static func validateOrientation(
        landmarks: PostureLandmarks,
        for angle: ScanAngle
    ) -> PoseOrientationValidationResult {
        switch angle {
        case .front:
            // 1. Must have facial landmarks visible (facing front)
            let hasFace = landmarks.nose != nil || landmarks.leftEye != nil || landmarks.rightEye != nil
            guard hasFace else {
                return .violation(message: "Turn around to face camera (Front View)")
            }
            
            // 2. Both shoulders must be visible
            guard let leftSh = landmarks.leftShoulder, let rightSh = landmarks.rightShoulder else {
                return .violation(message: "Both shoulders must be clearly visible")
            }
            
            // 3. Shoulders must be squared and wide (not in profile)
            let shoulderSpan = abs(leftSh.x - rightSh.x)
            guard shoulderSpan >= 0.15 else {
                return .violation(message: "Square your body directly to the camera")
            }
            
            // 4. Head must be centered between shoulders
            let minShX = min(leftSh.x, rightSh.x)
            let maxShX = max(leftSh.x, rightSh.x)
            if let nose = landmarks.nose {
                guard nose.x >= minShX && nose.x <= maxShX else {
                    return .violation(message: "Center your head between your shoulders")
                }
            }
            return .valid
            
        case .right:
            // REJECT FRONT OR BACK VIEWS:
            // A. Wide shoulders indicate facing front or back
            if let span = landmarks.shoulderWidth, span > 0.14 {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // B. Both eyes visible indicates facing camera
            if landmarks.leftEye != nil && landmarks.rightEye != nil {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // C. Both ears visible horizontally separated indicates facing camera
            if let lEar = landmarks.leftEar, let rEar = landmarks.rightEar, abs(lEar.x - rEar.x) > 0.035 {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // POSITIVE PROFILE REQUIREMENTS:
            let hasEar = landmarks.leftEar != nil || landmarks.rightEar != nil
            let hasProfileAnchor = landmarks.nose != nil || landmarks.neck != nil
            guard hasEar && hasProfileAnchor else {
                return .violation(message: "Keep your side profile in frame")
            }
            
            guard landmarks.leftShoulder != nil || landmarks.rightShoulder != nil else {
                return .violation(message: "Keep your side profile in view")
            }
            return .valid
            
        case .left:
            // REJECT FRONT OR BACK VIEWS:
            // A. Wide shoulders indicate facing front or back
            if let span = landmarks.shoulderWidth, span > 0.14 {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // B. Both eyes visible indicates facing camera
            if landmarks.leftEye != nil && landmarks.rightEye != nil {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // C. Both ears visible horizontally separated indicates facing camera
            if let lEar = landmarks.leftEar, let rEar = landmarks.rightEar, abs(lEar.x - rEar.x) > 0.035 {
                return .violation(message: "Turn 90° sideways to camera")
            }
            
            // POSITIVE PROFILE REQUIREMENTS:
            let hasEar = landmarks.leftEar != nil || landmarks.rightEar != nil
            let hasProfileAnchor = landmarks.nose != nil || landmarks.neck != nil
            guard hasEar && hasProfileAnchor else {
                return .violation(message: "Keep your side profile in frame")
            }
            
            guard landmarks.leftShoulder != nil || landmarks.rightShoulder != nil else {
                return .violation(message: "Keep your side profile in view")
            }
            return .valid
            
        case .back:
            // REJECT FRONT OR SIDE VIEWS:
            // A. Nose, left eye, or right eye MUST NOT be visible when facing back!
            if landmarks.nose != nil || landmarks.leftEye != nil || landmarks.rightEye != nil {
                return .violation(message: "Turn around — your back must face the camera")
            }
            
            // POSITIVE DORSAL REQUIREMENTS:
            // B. Both shoulders must be visible from the back
            guard landmarks.leftShoulder != nil && landmarks.rightShoulder != nil else {
                return .violation(message: "Stand with your back and shoulders visible")
            }
            
            // C. Shoulders must be squared/wide from the back (not turned sideways)
            if let span = landmarks.shoulderWidth, span < 0.14 {
                return .violation(message: "Square your back to the camera")
            }
            
            // D. Neck/spine must be visible
            guard landmarks.neck != nil else {
                return .violation(message: "Keep your upper back and neck in view")
            }
            return .valid
        }
    }
}
