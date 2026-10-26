import Foundation

/// Turns side-view joints into posture angles, and a run of frames into an assessment.
///
/// The angles come from a 2D pose estimate, so they are approximate: they depend on the
/// camera being level and square to the person's side, and on the estimate itself.
nonisolated enum PostureMetrics {
    /// How framed the person is right now, for live guidance.
    enum Framing: Equatable, Sendable {
        case noPerson
        /// A person is visible, but not enough of the head, shoulder and hip.
        case partial
        case good
    }

    /// Angles for one frame. Each is nil when the joints it needs weren't clear.
    struct Angles: Equatable, Sendable {
        var headForward: Double?
        var trunkLean: Double?
    }

    static func framing(_ frame: PoseFrame) -> Framing {
        guard let joints = frame.joints else { return .noPerson }
        let a = angles(joints)
        return a.headForward != nil && a.trunkLean != nil ? .good : .partial
    }

    static func angles(_ joints: SideViewJoints) -> Angles {
        let nose = usable(joints.nose)
        let ear = usable(joints.ear)
        let shoulder = usable(joints.shoulder)
        let hip = usable(joints.hip)
        // The nose shows which way the person faces; without it "forward" is unknown.
        guard let nose, let ear, let shoulder else { return Angles() }
        let facing: Double = nose.x >= ear.x ? 1 : -1
        let head = angleFromVertical(from: shoulder, to: ear, facing: facing)
        let trunk = hip.map { angleFromVertical(from: $0, to: shoulder, facing: facing) }
        return Angles(headForward: head, trunkLean: trunk)
    }

    /// Degrees that the line `from → to` leans forward of vertical. Negative leans back.
    static func angleFromVertical(from lower: BodyPoint, to upper: BodyPoint, facing: Double) -> Double {
        let dx = (upper.x - lower.x) * facing
        let dy = upper.y - lower.y
        return atan2(dx, dy) * 180 / .pi
    }

    static func assessment(
        frames: [PoseFrame],
        startedAt: Date,
        endedAt: Date,
        activeSeconds: TimeInterval,
        id: UUID = UUID()
    ) -> PostureAssessment {
        let all = frames.map { $0.joints.map(angles) ?? Angles() }
        let heads = all.compactMap(\.headForward)
        let trunks = all.compactMap(\.trunkLean)
        let headOK = heads.count >= PostureThresholds.minimumFrames
        let trunkOK = trunks.count >= PostureThresholds.minimumFrames
        return PostureAssessment(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            framesAnalysed: frames.count,
            headFrames: heads.count,
            trunkFrames: trunks.count,
            headForwardMedian: headOK ? median(heads) : nil,
            headForwardShare: headOK ? share(heads, above: PostureThresholds.headForward) : nil,
            trunkLeanMedian: trunkOK ? median(trunks) : nil,
            trunkLeanShare: trunkOK ? share(trunks, above: PostureThresholds.trunkLean) : nil
        )
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    static func share(_ values: [Double], above threshold: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.filter { $0 > threshold }.count) / Double(values.count)
    }

    private static func usable(_ point: BodyPoint?) -> BodyPoint? {
        guard let point, point.confidence >= PostureThresholds.minimumConfidence else { return nil }
        return point
    }
}
