import SwiftUI

/// Spacing scale. Screens use `screenMargin` for horizontal insets.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let screenMargin: CGFloat = 20
}

enum Radius {
    static let control: CGFloat = 12
    static let plate: CGFloat = 20
}

/// Minimum tappable size; larger than the 44pt HIG minimum for this audience.
enum TouchTarget {
    static let minimum: CGFloat = 48
    static let primaryControl: CGFloat = 72
}

enum Motion {
    /// The one animation used for state changes across the app.
    static let standard = Animation.smooth(duration: 0.35)

    static func standard(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : standard
    }
}

/// Design tokens. Neutrals are native semantic colours so Light Mode, Dark Mode and
/// Increase Contrast come from the system; the two brand accents live in the asset catalog.
/// Change a colour here (or in its colour set) and every screen follows.
extension ShapeStyle where Self == Color {
    static var impostureBackground: Color { Color(.systemGroupedBackground) }
    static var impostureSurface: Color { Color(.secondarySystemGroupedBackground) }
    static var impostureSurfaceEmphasis: Color { Color(.secondarySystemFill) }
    static var impostureSeparator: Color { Color(.separator) }
    static var impostureTextPrimary: Color { Color(.label) }
    static var impostureTextSecondary: Color { Color(.secondaryLabel) }
    static var impostureDisabled: Color { Color(.tertiarySystemFill) }

    /// Brand accent (#A9CC53). Fill for buttons, selected states and progress.
    static var impostureAccentFill: Color { .brandAccentFill }
    /// Soft fill for selected states, always paired with a non-colour indicator.
    static var impostureAccentSoft: Color { .brandAccentSoft }
    /// Text and icons placed on `impostureAccentFill`.
    static var impostureOnAccent: Color { .brandOnAccent }
    /// The brand accent as text or a small icon. Deepened in Light Mode to keep 4.5:1 contrast.
    static var impostureAccentText: Color { .brandAccentText }
    /// Provisional secondary accent (#B8A8CC) for subtle highlights such as completed states.
    /// Deepened in Light Mode so icons and text stay legible.
    static var impostureSecondaryAccent: Color { .brandSecondaryAccent }
    /// The secondary accent at full lightness, for soft glows and illustrations only.
    static var impostureGlow: Color { .brandSecondaryGlow }
    /// Fixed light backing for illustrations, which are drawn for a light surface.
    static var impostureIllustrationPlate: Color { .brandIllustrationPlate }

    // MARK: Progress dashboard
    // A fixed charcoal-and-green palette for the data-dense Progress screens. Green only:
    // no red, purple or blue, so status never relies on a second hue.

    static var impostureDashboardBackground: Color { .brandDashboardBackground }
    static var impostureDashboardCard: Color { .brandDashboardCard }
    /// Tracks, badges and empty segments that sit on a card.
    static var impostureDashboardElevated: Color { .brandDashboardElevated }
    static var impostureDashboardText: Color { .brandDashboardText }
    static var impostureDashboardTextSecondary: Color { .brandDashboardTextSecondary }
    /// Highlights and values on the brand green.
    static var impostureGreenLight: Color { .brandGreenLight }
    /// Secondary data series and quieter green fills.
    static var impostureGreenDeep: Color { .brandGreenDeep }
}

/// The brand's only gradients. Each blends neighbouring greens or charcoals, so transitions stay
/// low-contrast. Use them sparingly: primary actions, active progress, score visuals and the one
/// focal card on a screen. Never on every card, button or background.
enum BrandGradient {
    /// Primary actions and active progress. Dark labels on it stay above 8:1.
    static let primary = LinearGradient(colors: [.impostureAccentFill, .impostureGreenLight], startPoint: .leading, endPoint: .trailing)
    /// Supporting fills, such as the leading end of a progress ring.
    static let deep = LinearGradient(colors: [.impostureGreenDeep, .impostureAccentFill], startPoint: .leading, endPoint: .trailing)
    /// A screen background that lifts very slightly towards the bottom.
    static let background = LinearGradient(colors: [.impostureDashboardBackground, .impostureDashboardCard], startPoint: .top, endPoint: .bottom)
    /// Depth for a selected or focal card.
    static let card = LinearGradient(colors: [.impostureDashboardCard, .impostureDashboardElevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Score and progress rings: deep green turning to light green clockwise.
    static let ring = AngularGradient(
        colors: [.impostureGreenDeep, .impostureAccentFill, .impostureGreenLight],
        center: .center, startAngle: .degrees(0), endAngle: .degrees(360)
    )
}

extension View {
    /// Standard screen background.
    func impostureScreenBackground() -> some View {
        background(Color.impostureBackground.ignoresSafeArea())
    }
}
