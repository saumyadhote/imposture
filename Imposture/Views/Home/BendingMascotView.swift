import SwiftUI

/// The desk-lamp mascot (Figma "Group 38"), split into three layers on one canvas:
/// base (legs, chair, desk, lamp), upper body, and head. The upper body rotates around
/// the waist to hunch or sit straight; the head nods around the neck with phone tilt.
///
/// Sits up when Home appears, then falls into a hunch on its own. Drag it upwards to
/// straighten; let go past the threshold and it springs upright, then falls again.
struct BendingMascotView: View {
    let viewModel: MascotViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Non-nil while the person is dragging.
    @State private var dragStraightness: Double?
    @State private var reachedTop = false

    /// Art is 1024 × 969 px. Pivots are in unit coordinates of that canvas.
    private static let aspect = 1024.0 / 969.0
    private static let waist = UnitPoint(x: 0.2227, y: 0.4066)
    private static let neck = UnitPoint(x: 0.3789, y: 0.1827)

    private var straightness: Double {
        if let dragStraightness { return dragStraightness }
        return viewModel.pose == .upright ? 1 : 0
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            artwork
            Label(viewModel.pose == .upright ? "Nice and tall" : "Drag gogo up to sit straight", systemImage: "hand.draw")
                .font(.footnote)
                .foregroundStyle(Color.impostureTextSecondary)
                .accessibilityHidden(true)
        }
    }

    private var artwork: some View {
        ZStack {
            LampGlow(shape: .beam, opacity: 1)
            LampGlow(shape: .floor, opacity: 0.38)
            layer(.mascotLampBase)
            ZStack {
                layer(.mascotLampTorso)
                layer(.mascotLampHead)
                    // Lifts when sitting straight (animated with the pose)…
                    .rotationEffect(.degrees(SlouchPose.uprightHeadLift * min(max(straightness, 0), 1)), anchor: Self.neck)
                    // …and nods with phone tilt (already smoothed, so not animated).
                    .rotationEffect(.degrees(viewModel.leanFraction * SlouchPose.maxNod), anchor: Self.neck)
            }
            .rotationEffect(.degrees(SlouchPose.spine(straightness: straightness)), anchor: Self.waist)
            LampGlow(shape: .beam, opacity: 0.6)
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .contentShape(.rect)
        .gesture(drag)
        .onTapGesture { viewModel.resetPosture() }
        .task { viewModel.sitUpThenFall() }
        .animation(dragStraightness == nil ? poseAnimation : nil, value: viewModel.pose)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.resetCount)
        .sensoryFeedback(.selection, trigger: reachedTop)
        .accessibilityElement()
        .accessibilityLabel(viewModel.pose == .upright ? "gogo, sitting up straight" : "gogo, hunched over a laptop")
        .accessibilityHint("Drag up, or double-tap, to help gogo sit straight")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { viewModel.resetPosture() }
        .accessibilityIdentifier("home.mascot")
    }

    private func layer(_ image: ImageResource) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let s = SlouchPose.straightness(forDrag: value.translation.height)
                dragStraightness = s
                if (s >= 1) != reachedTop { reachedTop = s >= 1 }
            }
            .onEnded { _ in
                let s = dragStraightness ?? 0
                withAnimation(releaseAnimation) {
                    dragStraightness = nil
                    if SlouchPose.shouldStand(afterReleaseAt: s) { viewModel.resetPosture() }
                }
                reachedTop = false
            }
    }

    /// The "drop": a bouncy settle when let go.
    private var releaseAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.35)
    }

    /// Springs upright quickly; falls back into the hunch under its own weight,
    /// overshooting a little before it settles.
    private var poseAnimation: Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }
        return viewModel.pose == .upright ? .spring(duration: 0.5, bounce: 0.3) : .spring(duration: 1.0, bounce: 0.3)
    }
}

/// The blurred lamp light from the Figma artwork, in unit coordinates of the art.
private struct LampGlow: View {
    enum Shape {
        case beam
        case floor

        var points: [CGPoint] {
            switch self {
            case .beam: [CGPoint(x: 0.6223, y: 0.3153), CGPoint(x: 0.8135, y: 0.1279), CGPoint(x: 0.8135, y: 0.1344), CGPoint(x: 0.7689, y: 0.3504)]
            case .floor: [CGPoint(x: 0.0751, y: 0.7500), CGPoint(x: 0.1162, y: 0.6957), CGPoint(x: 0.7870, y: 0.7187), CGPoint(x: 0.2216, y: 0.7851)]
            }
        }
    }

    let shape: Shape
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.addLines(shape.points.map { CGPoint(x: $0.x * proxy.size.width, y: $0.y * proxy.size.height) })
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [Color(red: 0xF0 / 255, green: 0xDD / 255, blue: 0x8F / 255), Color(red: 1, green: 0xCC / 255, blue: 0)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .blur(radius: 15 * proxy.size.width / 402)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    BendingMascotView(viewModel: MascotViewModel(tiltSource: MotionManager()))
        .padding()
        .impostureScreenBackground()
}
