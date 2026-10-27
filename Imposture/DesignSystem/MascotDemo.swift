import SwiftUI

/// Pre-rendered mascot loops from Blender, bundled as H.264 MP4s in Resources.
///
/// One rigged character (`GG_Rig` in gogo_character.blend) renders a loop per exercise;
/// an exercise points at its loop through `Exercise.animation`. Adding a loop needs no code:
/// drop `mascot_<name>.mp4` in Resources and set `"animation"` in Library.json.
enum MascotAnimation {
    /// Shown on Home when the next session has no loop of its own.
    /// PLACEHOLDER: the only render so far is shoulder rolls; an idle loop is still to be made.
    static let hero = "mascot_shoulder_rolls"
    /// PLACEHOLDER until a celebration loop is rendered.
    static let celebration = "mascot_shoulder_rolls"

    static func isBundled(_ name: String) -> Bool {
        Bundle.main.url(forResource: name, withExtension: "mp4") != nil
    }
}

/// The mascot demonstrating a movement. Uses, in order: the rendered 3D loop, the drawn
/// exercise figure, or a quiet placeholder that says the demo isn't ready.
struct MascotDemo: View {
    let animation: String?
    var figure: String?
    var systemImage = "figure.mind.and.body"
    var label: String

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(exercise: Exercise) {
        animation = exercise.animation
        figure = Artwork.figure(for: exercise.id)
        systemImage = exercise.category.systemImage
        label = exercise.animation == nil
            ? exercise.illustrationDescription
            : "The mascot demonstrating \(exercise.name.lowercased())"
    }

    init(animation: String, label: String) {
        self.animation = animation
        self.label = label
    }

    var body: some View {
        Group {
            if !Artwork.showsIllustrations {
                IllustrationPlaceholder(label: "Exercise demo placeholder")
                    .padding(Spacing.md)
            } else if let animation, MascotAnimation.isBundled(animation) {
                // Fill so the figure is large; edges fade so the render's backdrop melts away.
                LoopingVideo(resource: animation, contentMode: .fill, fadesEdges: true)
            } else if let figure {
                Image(figure)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.lg)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(.largeTitle, weight: .light))
                .imageScale(.large)
                .foregroundStyle(Color.impostureSecondaryAccent)
            Text("Demo coming soon")
                .font(.footnote)
                .foregroundStyle(Color.impostureTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if !reduceTransparency {
                RadialGradient(colors: [Color.impostureGlow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 160)
            }
        }
    }
}

/// Small square thumbnail for an exercise: its drawn figure, or the category symbol.
struct ExerciseThumbnail: View {
    let exercise: Exercise
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Color.impostureDashboardElevated
            if let figure = Artwork.figure(for: exercise.id) {
                Image(figure)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                Image(systemName: exercise.category.systemImage)
                    .font(.system(size: size * 0.4, weight: .light))
                    .foregroundStyle(Color.impostureGreenLight)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityHidden(true)
    }
}
