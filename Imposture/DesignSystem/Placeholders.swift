import SwiftUI

/// A plain text label marking where artwork will go. No box, so it reads as a note rather
/// than as a broken image. Swap it for the real illustration when one exists.
struct IllustrationPlaceholder: View {
    var label = "Illustration placeholder"

    var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(Color.impostureDashboardTextSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
    }
}

/// The imposture wordmark: a symbol and the app name, with the brand green.
/// Temporary until the real logo is ready; replace this one view.
/// Replace this one view when the real logo is ready.
struct BrandMark: View {
    @ScaledMetric(relativeTo: .title2) private var badge: CGFloat = 36

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "figure.stand")
                .font(.system(size: badge * 0.5, weight: .semibold))
                .foregroundStyle(Color.impostureOnAccent)
                .frame(width: badge, height: badge)
                .background(BrandGradient.primary, in: .circle)
            Text("imposture")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("imposture")
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        BrandMark()
        IllustrationPlaceholder(label: "Desk setup preview")
    }
    .padding()
    .background(Color.impostureDashboardBackground)
}
