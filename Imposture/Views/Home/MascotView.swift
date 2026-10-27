import SwiftUI

/// The mascot artwork Home shows, and how it can move.
enum MascotArtwork {
    enum Style {
        /// Desk worker with a lamp (Figma "Group 38"), in base / upper-body / head layers:
        /// the back hunches and straightens, the head nods. See `BendingMascotView`.
        case bendingDesk
        /// Desk worker with a separate head layer. The head and upper neck nod
        /// about the base of the neck while the body, chair and desk stay still.
        case noddingHead
        /// Separate scene and character layers (from `gogo_low_fidelity_mascot.svg`).
        /// The whole character leans and sits up while the desk stays still.
        case layered
    }

    /// Current artwork. `.noddingHead` and `.layered` bring back the earlier mascots.
    static let style: Style = .bendingDesk

    // MARK: Nodding-head artwork
    // Split from "Tired Worker at a Cluttered Desk.png", then both layers cropped to
    // the same 1176×832 rect (x 216, y 152 of the original), so they stack exactly.
    // The head layer overlaps the body by 3px along the cut, which hides the seam.

    static let workerBody: ImageResource = .mascotWorkerBody
    static let workerHead: ImageResource = .mascotWorkerHead

    /// Middle of the cut across the neck, in unit coordinates of the canvas.
    static let neckPivot = UnitPoint(x: 0.3078, y: 0.2181)

    /// Furthest the head turns either way, in degrees. Past about 12° a small nick
    /// shows where the head layer meets the neck; 20° trades that for a clearer slouch.
    static let maxNod = 20.0

    // MARK: Layered artwork. Layers share one viewBox (95 150 670 410), so they stack exactly.

    static let scene: ImageResource = .mascotScene
    static let strainMarks: ImageResource = .mascotStrain

    /// PLACEHOLDER: there is no upright artwork yet, so both poses use the slouched
    /// drawing and `MascotView` fakes sitting up with a transform. When an upright
    /// drawing exists, return it for `.upright` and set `hasUprightArtwork` to true.
    static func character(for pose: MascotPose) -> ImageResource {
        .mascotCharacter
    }

    static let hasUprightArtwork = false

    /// Where the body meets the seat, in unit coordinates of the shared viewBox.
    /// Every character transform pivots here so the figure stays on the chair.
    static let hipAnchor = UnitPoint(x: 0.351, y: 0.671)
}

/// Mascot at its desk. Responds to phone tilt; tap for a posture reset.
struct MascotView: View {
    let viewModel: MascotViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if case .bendingDesk = MascotArtwork.style {
            BendingMascotView(viewModel: viewModel)
        } else {
            tappableArtwork
        }
    }

    private var tappableArtwork: some View {
        Button {
            viewModel.resetPosture()
        } label: {
            artwork
                .background {
                    EllipticalGradient(
                        colors: [Color.impostureGlow.opacity(glowOpacity), Color.impostureGlow.opacity(0)],
                        endRadiusFraction: 0.5
                    )
                    .padding(-Spacing.xxl)
                    .animation(poseAnimation, value: viewModel.pose)
                    .accessibilityHidden(true)
                }
                .contentShape(.rect)
        }
        .buttonStyle(MascotPressStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.resetCount)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Gives gogo a posture reset")
        .accessibilityIdentifier("home.mascot")
    }

    @ViewBuilder private var artwork: some View {
        switch MascotArtwork.style {
        case .noddingHead, .bendingDesk:
            noddingHeadArtwork
        case .layered:
            ZStack {
                Image(MascotArtwork.scene)
                    .resizable()
                    .scaledToFit()
                layeredCharacter
            }
        }
    }

    private var accessibilityLabel: String {
        switch MascotArtwork.style {
        case .noddingHead, .bendingDesk: isUpright ? "gogo, head lifted, looking ahead" : "gogo, head drooping toward a laptop"
        case .layered: viewModel.pose == .upright ? "gogo, sitting up tall" : "gogo, slouched over a laptop"
        }
    }

    private var isUpright: Bool { viewModel.pose == .upright }

    /// The halo brightens during a reset, as a sign of relief.
    private var glowOpacity: Double { isUpright ? 0.38 : 0.22 }

    // MARK: - Nodding head
    // Tilting the phone right lets the head droop further toward the laptop; tilting
    // left lifts it. Tapping lifts the head to look ahead (a real posture change for
    // the neck), then it slowly droops again. The back and shoulders can't move,
    // because they're merged with the chair in the artwork.

    private var noddingHeadArtwork: some View {
        ZStack {
            Image(MascotArtwork.workerBody)
                .resizable()
                .scaledToFit()
            Image(MascotArtwork.workerHead)
                .resizable()
                .scaledToFit()
                // Pose: animated by SwiftUI when the pose changes.
                .rotationEffect(.degrees(headLift), anchor: MascotArtwork.neckPivot)
                .animation(poseAnimation, value: viewModel.pose)
                // Tilt: already smoothed by the view model, so applied without animation.
                .rotationEffect(.degrees(viewModel.leanFraction * MascotArtwork.maxNod), anchor: MascotArtwork.neckPivot)
        }
        .shadow(color: Color.impostureTextPrimary.opacity(0.14), radius: 18)
    }

    /// Lifting the head is the reset, so it shows even with Reduce Motion (just without the spring).
    private var headLift: Double {
        isUpright ? -MascotArtwork.maxNod : 0
    }

    // MARK: - Layered artwork

    private var layeredCharacter: some View {
        ZStack {
            Image(MascotArtwork.character(for: viewModel.pose))
                .resizable()
                .scaledToFit()
            // The marks are drawn in dark ink for a light backdrop; tint them so they read on charcoal.
            Image(MascotArtwork.strainMarks)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Color.impostureTextSecondary)
                .opacity(isUpright ? 0 : 1)
        }
        .shadow(color: Color.impostureTextPrimary.opacity(0.18), radius: 16)
        .scaleEffect(x: 1, y: layeredStretch, anchor: MascotArtwork.hipAnchor)
        .rotationEffect(.degrees(layeredRotation), anchor: MascotArtwork.hipAnchor)
        .animation(poseAnimation, value: viewModel.pose)
        .rotationEffect(.degrees(viewModel.lean), anchor: MascotArtwork.hipAnchor)
    }

    // Without upright artwork, "sitting up" is a small lean back plus a slight
    // lengthening around the hips. The spine and neck can't really straighten,
    // because the body is one drawn shape.

    private var showsLayeredPlaceholder: Bool {
        !MascotArtwork.hasUprightArtwork && !reduceMotion
    }

    private var layeredRotation: Double {
        isUpright && showsLayeredPlaceholder ? -7 : 0
    }

    private var layeredStretch: Double {
        isUpright && showsLayeredPlaceholder ? 1.04 : 1
    }

    private var poseAnimation: Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }
        // Snap up quickly; sink back slowly, like a real slouch returning.
        return isUpright ? .spring(duration: 0.45, bounce: 0.3) : .smooth(duration: 1.4)
    }
}

/// A slight press-down so the tap registers before the reset plays.
private struct MascotPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MascotView(viewModel: MascotViewModel(tiltSource: MotionManager()))
        .padding()
        .background(Color.impostureBackground)
}
