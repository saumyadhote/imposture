import Foundation

/// Turns raw phone tilt into a small, calm lean angle for the mascot.
///
/// Small tilts are ignored, so a resting hand reads as neutral. Beyond that the
/// lean grows gently, is clamped, and is low-pass filtered to remove jitter.
struct TiltFilter {
/// Phone tilt, in degrees, that still counts as level.
var deadZone = 0.3

/// Mascot degrees per phone degree beyond the dead zone.
var gain = 4.5

/// Largest neck lean, in degrees, either way.
var maxLean = 90.0

/// Smoothing time in seconds. Smaller responds faster.
var timeConstant = 0.08



    private(set) var value = 0.0

    /// The lean the filter is heading toward for a given phone tilt.
    func target(forRoll roll: Double) -> Double {
        let beyondDeadZone = max(abs(roll) - deadZone, 0)
        let lean = min(beyondDeadZone * gain, maxLean)
        return roll < 0 ? -lean : lean
    }

    /// Moves toward the target for `roll` over `dt` seconds and returns the new lean.
    @discardableResult
    mutating func update(roll: Double, dt: TimeInterval) -> Double {
        let target = target(forRoll: roll)
        let step = 1 - exp(-max(dt, 0) / timeConstant)
        value += (target - value) * step
        if target == 0, abs(value) < 0.01 {
            value = 0
        }
        return value
    }

    mutating func reset() {
        value = 0
    }
}
