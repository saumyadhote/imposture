import SwiftUI

/// A softly lit, realistic 3D sphere rendered in native SwiftUI with layered gradients.
/// Features smooth transitions from a bright lime-green highlight to deep olive shadows,
/// diffused lighting, natural edge shading, and an ambient dark-theme glow.
struct AuroraOrb: View {
    var size: CGFloat = 220
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Color Palette
    /// Primary lime accent (#C6E85A)
    private static let limeAccent = Color(red: 0xC6 / 255.0, green: 0xE8 / 255.0, blue: 0x5A / 255.0)
    /// Soft luminous yellow-green highlight (#DCF482)
    private static let yellowGreen = Color(red: 0xDC / 255.0, green: 0xF4 / 255.0, blue: 0x82 / 255.0)
    /// Muted sage midtone for organic transition (#8EA84E)
    private static let sageTone = Color(red: 0x8E / 255.0, green: 0xA8 / 255.0, blue: 0x4E / 255.0)
    /// Deep olive tone for natural shadows (#3E4D21)
    private static let deepOlive = Color(red: 0x3E / 255.0, green: 0x4D / 255.0, blue: 0x21 / 255.0)
    /// Dark olive tone for bottom and lower-right edges (#212A11)
    private static let darkOlive = Color(red: 0x21 / 255.0, green: 0x2A / 255.0, blue: 0x11 / 255.0)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            orb(at: t)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func orb(at t: TimeInterval) -> some View {
        let breathe = reduceMotion ? 1.0 : (1 + 0.016 * sin(t * 0.85))

        return ZStack {
            // 1. Ambient Glow (Halo): soft ambient radiance behind the sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.limeAccent.opacity(0.22),
                            Self.deepOlive.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.20,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)

            // 2. Diffused contact shadow for grounding in dark mode
            Circle()
                .fill(Self.darkOlive.opacity(0.40))
                .blur(radius: size * 0.10)
                .offset(x: size * 0.03, y: size * 0.06)
                .frame(width: size, height: size)

            // 3. Matte 3D Sphere Body
            ZStack {
                // Layer A: Base Volumetric Gradient
                // Transitions smoothly from lime accent in upper-left through sage to deep olive
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Self.limeAccent, location: 0.0),
                                .init(color: Self.sageTone, location: 0.50),
                                .init(color: Self.deepOlive, location: 0.82),
                                .init(color: Self.darkOlive, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.32, y: 0.28),
                            startRadius: size * 0.04,
                            endRadius: size * 0.90
                        )
                    )

                // Layer B: Deep Olive Natural Shadow (Lower-right & bottom falloff)
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: .clear, location: 0.38),
                                .init(color: Self.deepOlive.opacity(0.60), location: 0.72),
                                .init(color: Self.darkOlive.opacity(0.92), location: 1.0)
                            ],
                            center: UnitPoint(x: 0.28, y: 0.24),
                            startRadius: size * 0.25,
                            endRadius: size * 0.95
                        )
                    )

                // Layer C: Smooth directional shading to blend the bottom edge naturally
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.35),
                                .init(color: Self.deepOlive.opacity(0.30), location: 0.70),
                                .init(color: Self.darkOlive.opacity(0.65), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Layer D: Ambient Reflected Rim Light (Bounce light in shadow area)
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: .clear, location: 0.80),
                                .init(color: Self.sageTone.opacity(0.20), location: 0.94),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.74, y: 0.76),
                            startRadius: 0,
                            endRadius: size * 0.40
                        )
                    )

                // Layer E: Primary Diffused Highlight (Upper-Left)
                // Soft, large luminous highlight that creates a velvety matte surface
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Self.yellowGreen.opacity(0.80), location: 0.0),
                                .init(color: Self.limeAccent.opacity(0.40), location: 0.38),
                                .init(color: .clear, location: 0.72)
                            ],
                            center: UnitPoint(x: 0.32, y: 0.28),
                            startRadius: 0,
                            endRadius: size * 0.48
                        )
                    )

                // Layer F: Subtle Secondary Highlight
                // Delicately positioned for soft luminosity, avoiding hard plastic sheen
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.38), location: 0.0),
                                .init(color: Self.yellowGreen.opacity(0.18), location: 0.42),
                                .init(color: .clear, location: 0.85)
                            ],
                            center: UnitPoint(x: 0.28, y: 0.24),
                            startRadius: 0,
                            endRadius: size * 0.22
                        )
                    )

                // Layer G: Soft Edge Shading
                // Subtle curvature rim to eliminate any harsh edge artifact
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Self.yellowGreen.opacity(0.35), location: 0.0),
                                .init(color: Self.sageTone.opacity(0.15), location: 0.45),
                                .init(color: Self.darkOlive.opacity(0.75), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.0, size * 0.012)
                    )
            }
            .clipShape(Circle())
            .frame(width: size, height: size)
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
