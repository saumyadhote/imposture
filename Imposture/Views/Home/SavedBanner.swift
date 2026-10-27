import SwiftUI

/// Short confirmation that a just-finished session was saved.
struct SavedBanner: View {
    let session: CompletedSession
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityHidden(true)
            Text("Saved: \(session.title), \(DurationText.short(session.activeSeconds)) of movement.")
                .font(.subheadline)
                .foregroundStyle(Color.impostureTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.impostureTextSecondary)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, Spacing.md)
        .background(Color.impostureAccentSoft, in: .rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityIdentifier("home.saved")
    }
}
