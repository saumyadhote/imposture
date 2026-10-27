import SwiftUI

/// Full-width primary action: the green gradient with a dark label (over 8:1 contrast).
/// Shrinks slightly while pressed so the press always registers.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.impostureOnAccent : Color.impostureDashboardTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background {
                if isEnabled {
                    Capsule().fill(BrandGradient.primary)
                } else {
                    Capsule().fill(Color.impostureDashboardElevated)
                }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

/// Press feedback for whole cards and other large tappable surfaces.
struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

/// Full-width secondary action: the same capsule as the primary, on a quiet elevated fill.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.impostureDashboardText : Color.impostureDashboardTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background(Color.impostureDashboardElevated, in: .capsule)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

/// A round, icon-only control (back, previous, next) in the system's Liquid Glass style,
/// matching navigation bar buttons.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(label)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var imposturePrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var impostureSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
