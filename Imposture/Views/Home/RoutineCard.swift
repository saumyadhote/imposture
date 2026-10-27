import SwiftUI

/// Compact card that starts (or resumes) a routine. The whole card is the button.
struct RoutineCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let action: () -> Void

    private let cornerRadius = Radius.plate

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.impostureTextSecondary)
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.impostureTextPrimary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.impostureTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.impostureOnAccent)
                    .frame(width: 52, height: 52)
                    .background(Color.impostureAccentFill, in: .circle)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .background(Color.impostureSurface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.impostureSeparator, lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(CardPressStyle())
    }
}

private struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    RoutineCard(eyebrow: "Your next routine", title: "Desk Reset", detail: "5 min · 3 exercises") {}
        .padding()
        .background(Color.impostureBackground)
}
