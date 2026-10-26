import Foundation

/// Maps the mascot's posture and the phone's tilt to rotation angles, in degrees.
/// Positive leans forward (towards the desk).
///
/// `straightness` runs from 0 (hunched, at rest) to 1 (sitting straight). Dragging past
/// the top gives a little extra stretch, up to `maxStretch`.
enum SlouchPose {
    /// Upper body rotation at rest. Zero keeps the hunch exactly as drawn, so the arm
    /// meets the hand on the keyboard with no seam.
    static let restingHunch = 0.0
    /// Upper body rotation when sitting straight.
    static let uprightBend = -24.0
    /// Head nod at full phone tilt.
    static let maxNod = 20.0
    /// The head lifts this much more when sitting straight.
    static let uprightHeadLift = -12.0
    /// Upward drag, in points, that makes the mascot fully straight.
    static let dragDistance = 150.0
    /// Release above this and the mascot springs upright; below, it slumps back.
    static let standThreshold = 0.4
    static let maxStretch = 1.12

    static func spine(straightness: Double) -> Double {
        let s = max(0, straightness)
        return restingHunch + (uprightBend - restingHunch) * s
    }

    static func nod(leanFraction: Double, straightness: Double) -> Double {
        leanFraction * maxNod + uprightHeadLift * min(max(0, straightness), 1)
    }

    /// Straightness for a vertical drag (negative is up), rubber-banding past the top.
    static func straightness(forDrag dy: Double) -> Double {
        let raw = -dy / dragDistance
        guard raw > 1 else { return max(0, raw) }
        let excess = raw - 1
        return min(maxStretch, 1 + (maxStretch - 1) * excess / (excess + 0.6))
    }

    static func shouldStand(afterReleaseAt straightness: Double) -> Bool {
        straightness >= standThreshold
    }
}
