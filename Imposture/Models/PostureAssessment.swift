import Foundation

/// A body point from on-device pose estimation, in image points with y pointing up.
nonisolated struct BodyPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var confidence: Double
}

/// The joints a side-view assessment uses, from one camera frame. Any can be missing.
nonisolated struct SideViewJoints: Hashable, Sendable {
    var nose: BodyPoint?
    var ear: BodyPoint?
    var shoulder: BodyPoint?
    var hip: BodyPoint?
}

/// One pose estimate. `joints` is nil when no person was found in the frame.
nonisolated struct PoseFrame: Hashable, Sendable {
    var timestamp: TimeInterval
    var joints: SideViewJoints?
}

/// A finished side-view posture assessment. Only these numbers are stored: no images or video.
nonisolated struct PostureAssessment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    /// Time the assessment ran, excluding pauses.
    let activeSeconds: TimeInterval
    /// Frames analysed, and how many showed the head and shoulder, or shoulder and hip, clearly.
    let framesAnalysed: Int
    let headFrames: Int
    let trunkFrames: Int
    /// Median angle of the ear ahead of the shoulder, from vertical, in degrees.
    let headForwardMedian: Double?
    /// Share of head frames beyond `PostureThresholds.headForward`.
    let headForwardShare: Double?
    /// Median forward lean of the shoulder ahead of the hip, from vertical, in degrees.
    let trunkLeanMedian: Double?
    /// Share of trunk frames beyond `PostureThresholds.trunkLean`.
    let trunkLeanShare: Double?

    /// Share of analysed frames where the head and shoulder were clearly visible.
    var visibleShare: Double {
        framesAnalysed > 0 ? Double(headFrames) / Double(framesAnalysed) : 0
    }

    var isHeadAssessed: Bool { headForwardMedian != nil }
    var isTrunkAssessed: Bool { trunkLeanMedian != nil }
    var hasFindings: Bool { isHeadAssessed || isTrunkAssessed }
}

/// Reference angles for the report. These are uncalibrated app heuristics, not clinical
/// cut-offs, and need review before they're presented as anything more than a guide.
nonisolated enum PostureThresholds {
    static let headForward = 20.0
    static let trunkLean = 15.0
    /// Below this many usable frames a measurement isn't reported.
    static let minimumFrames = 20
    /// Joints below this confidence are ignored.
    static let minimumConfidence = 0.3
}
