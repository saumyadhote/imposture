import SwiftUI

/// Shown when a session ends: a short mascot celebration when it ran to the end,
/// a plain summary when it was ended early.
struct SessionCompleteView: View {
    let session: SessionViewModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var reachedEnd: Bool { session.reachedEnd }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: 0)

            if reachedEnd {
                celebration
            }

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.impostureTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(revealed ? 1 : 0)

            HStack(spacing: Spacing.xl) {
                Stat(value: DurationText.short(session.activeSeconds), label: "Total time")
                Stat(value: "\(session.completedCount) of \(session.plan.exercises.count)", label: "Exercises done")
            }
            .opacity(revealed ? 1 : 0)

            Spacer(minLength: 0)

            Button("Back to Home", action: onDone)
                .buttonStyle(.imposturePrimary)
                .accessibilityIdentifier("session.done")
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.md)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.8).delay(0.15)) {
                revealed = true
            }
        }
    }

    /// The mascot rises gently into a soft glow. Static with Reduce Motion.
    private var celebration: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.impostureGlow.opacity(0.35), Color.impostureAccentFill.opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 170
                ))
                .scaleEffect(revealed ? 1 : 0.6)
            MascotDemo(animation: MascotAnimation.celebration, label: "The mascot celebrating")
                .scaleEffect(revealed || reduceMotion ? 1 : 0.85)
                .offset(y: revealed || reduceMotion ? 0 : 24)
        }
        .frame(height: 300)
        .opacity(revealed || reduceMotion ? 1 : 0)
    }

    private var title: String {
        if reachedEnd {
            return session.plan.routineID.flatMap(Self.dayNumber).map { "Day \($0) complete" } ?? "Session complete"
        }
        return session.result == nil ? "Session ended" : "Nice work"
    }

    private var message: String {
        if reachedEnd { return session.plan.title }
        if session.result == nil {
            return "This one was too short to save."
        }
        return "Saved what you did. The session isn't marked complete."
    }

    /// "day-3" → 3.
    private static func dayNumber(_ routineID: String) -> Int? {
        guard routineID.hasPrefix("day-") else { return nil }
        return Int(routineID.dropFirst(4))
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.impostureTextPrimary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.impostureTextSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let session = SessionViewModel.preview()
    session.end()
    return SessionCompleteView(session: session) {}
        .impostureScreenBackground()
}
