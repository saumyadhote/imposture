import SwiftUI

/// A softly lit sphere in the brand greens that turns slowly and breathes.
/// Drawn with gradients, so it needs no 3D assets. Holds still with Reduce Motion.
struct AuroraOrb: View {
    var size: CGFloat = 220
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            orb(at: t)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func orb(at t: TimeInterval) -> some View {
        let breathe = 1 + 0.025 * sin(t * 0.9)
        return ZStack {
            // Halo
            Circle()
                .fill(RadialGradient(
                    colors: [Color.impostureAccentFill.opacity(0.28), Color.impostureGreenDeep.opacity(0.14), .clear],
                    center: .center, startRadius: size * 0.2, endRadius: size * 0.75
                ))
                .frame(width: size * 1.5, height: size * 1.5)
            // Body: a slowly turning band of colour, softened.
            Circle()
                .fill(AngularGradient(
                    colors: [.impostureGreenDeep, .impostureAccentFill, .impostureGreenLight, .impostureAccentFill, .impostureGreenDeep],
                    center: .center,
                    angle: .degrees(t * 12)
                ))
                .blur(radius: size * 0.08)
                .overlay {
                    // Wandering inner light, for depth.
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: size * 0.3))
                        .offset(x: size * 0.12 * cos(t * 0.5), y: size * 0.1 * sin(t * 0.7))
                        .blendMode(.screen)
                }
                .clipShape(.circle)
            // Shading: lit from the top left, falling into soft shade.
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.3), .clear, Color.black.opacity(0.35)],
                    center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: size * 0.7
                ))
        }
        .frame(width: size, height: size)
        .scaleEffect(breathe)
    }
}

#Preview {
    AuroraOrb()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .impostureScreenBackground()
}
