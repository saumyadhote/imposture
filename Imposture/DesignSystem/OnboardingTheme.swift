import SwiftUI

/// Adapter for the body-scan onboarding (ported from vyam): its colour and type names, backed
/// by this app's tokens, so the onboarding shares the app's palette and scales with Dynamic Type.
enum AppTheme {
    static var background: Color { .impostureDashboardBackground }
    static var surface: Color { .impostureDashboardCard }
    static var surfaceEmphasis: Color { .impostureDashboardElevated }
    static var limeAccent: Color { .impostureAccentFill }
    static var limeAccentSoft: Color { .impostureAccentFill.opacity(0.18) }
    static var textPrimary: Color { .impostureDashboardText }
    static var textSecondary: Color { .impostureDashboardTextSecondary }
    static var separator: Color { .white.opacity(0.08) }
    static var dotInactive: Color { .white.opacity(0.3) }
    static var dotActive: Color { .white }

    static func titleFont() -> Font { .largeTitle.weight(.bold) }
    static func bodyFont() -> Font { .callout.weight(.medium) }
    static func buttonFont() -> Font { .headline }

    static var largeTitle: Font { .largeTitle.weight(.bold) }
    static var title: Font { .largeTitle.weight(.bold) }
    static var headline: Font { .headline }
    static var body: Font { .callout.weight(.medium) }
    static var subheadline: Font { .subheadline }
    static var caption: Font { .footnote.weight(.medium) }
    static var button: Font { .headline }
}

/// A named onboarding illustration, or a labelled placeholder while illustrations are off.
struct OnboardingArt: View {
    let name: String
    let label: String
    var height: CGFloat = 220

    var body: some View {
        if Artwork.showsIllustrations {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: height)
                .accessibilityLabel(label)
        } else {
            IllustrationPlaceholder(label: label)
        }
    }
}

/// The onboarding's full-width capsule button, drawn with the app's primary style.
struct AppButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let icon {
                Label(title, systemImage: icon)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.imposturePrimary)
    }
}
