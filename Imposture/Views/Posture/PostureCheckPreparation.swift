import SwiftUI

/// The five screens before a camera posture check, pushed in order on the Posture tab's stack.
/// None of them touch the camera; permission is only asked for once the check itself opens.
enum PostureCheckStep: Int, CaseIterable, Hashable {
    case prepare
    case chairAndScreen
    case armsAndLegs
    case reminder
    case phone

    var next: PostureCheckStep? { PostureCheckStep(rawValue: rawValue + 1) }

    /// Segments lit in the four-part progress bar. The reminder is an aside, so it doesn't advance it.
    var progress: Int {
        switch self {
        case .prepare: 1
        case .chairAndScreen: 2
        case .armsAndLegs, .reminder: 3
        case .phone: 4
        }
    }

    /// Where the bar starts before animating forward, so each step shows its own progress being made.
    var previousProgress: Int {
        switch self {
        case .prepare: 0
        default: PostureCheckStep(rawValue: rawValue - 1)?.progress ?? 0
        }
    }
}

struct PostureCheckStepView: View {
    let step: PostureCheckStep
    let advance: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                content
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.impostureDashboardBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: advance) {
                Text(ctaTitle)
            }
            .buttonStyle(.imposturePrimary)
            .accessibilityIdentifier("prepare.next")
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
            .background(Color.impostureDashboardBackground)
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .prepare:
            StepHeader(label: "Before your camera session", title: "Let's get comfortable.", message: "A quick desk setup helps you begin in a supported position.")
            StepProgress(step: step)
            IllustrationPlaceholder(label: "Desk setup preview")
            Label("4 quick steps · About 30 seconds", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(Color.impostureDashboardTextSecondary)

        case .chairAndScreen:
            StepHeader(label: "Step 1 of 4", title: "Set up your chair and screen.", message: "Aim for comfort and support, not a rigid pose.")
            StepProgress(step: step)
            IllustrationPlaceholder(label: "Seating position preview")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ChecklistRow(text: "Back supported, shoulders relaxed")
                ChecklistRow(text: "Screen near eye level, about arm's length")
            }

        case .armsAndLegs:
            StepHeader(label: "Step 2 of 4", title: "Relax your arms. Support your feet.", message: "Small adjustments make desk work more comfortable.")
            StepProgress(step: step)
            VStack(spacing: Spacing.sm) {
                InstructionCard(symbol: "hand.raised", title: "Elbows & wrists", text: "Elbows near your sides; wrists relaxed.")
                InstructionCard(symbol: "figure.seated.side.right", title: "Hips & knees", text: "Knees near hip level, with seat clearance.")
                InstructionCard(symbol: "shoeprints.fill", title: "Feet", text: "Flat on the floor or resting on a footrest.")
            }

        case .reminder:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("A LITTLE REMINDER")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.impostureAccentFill)
                Text("There's no single perfect sitting posture.")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.impostureDashboardText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Capsule()
                    .fill(BrandGradient.primary)
                    .frame(width: 48, height: 3)
                    .accessibilityHidden(true)
                Text("Comfortable support and regular movement matter more than maintaining exact angles.")
                    .font(.body)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            InstructionCard(symbol: "figure.cooldown", title: "Stay comfortable", text: "It's okay to shift, stretch, and change positions during your session.")

        case .phone:
            StepHeader(label: "Step 3 of 4", title: "Position your phone.", message: "Make sure your head, shoulders, and upper body stay visible.")
            StepProgress(step: step)
            IllustrationPlaceholder(label: "Phone positioning preview")
            Text("Place the phone at a stable angle with clear lighting.")
                .font(.subheadline)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
        }
    }

    private var ctaTitle: String {
        switch step {
        case .prepare: "Set up my posture →"
        case .chairAndScreen: "Next: Arms & legs →"
        case .armsAndLegs: "Next: A reminder →"
        case .reminder: "Got it →"
        case .phone: "Ready to begin →"
        }
    }
}

// MARK: - Pieces

private struct StepHeader: View {
    let label: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Color.impostureAccentFill)
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Four segments. On appear, the newly reached segment fills, so moving forward is felt.
private struct StepProgress: View {
    let step: PostureCheckStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit: Int

    init(step: PostureCheckStep) {
        self.step = step
        _lit = State(initialValue: step.previousProgress)
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Color.impostureDashboardElevated)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(BrandGradient.primary)
                                .frame(width: index < lit ? proxy.size.width : 0)
                        }
                    }
                    .clipShape(.capsule)
            }
        }
        .frame(height: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preparation progress")
        .accessibilityValue("\(step.progress) of 4")
        .task {
            guard lit != step.progress else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.15)) { lit = step.progress }
        }
    }
}

private struct ChecklistRow: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Color.impostureDashboardText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.impostureAccentFill)
        }
        .font(.body)
    }
}

private struct InstructionCard: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.impostureGreenLight)
                .frame(width: 44, height: 44)
                .background(Color.impostureDashboardElevated, in: .rect(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        PostureCheckStepView(step: .armsAndLegs) {}
    }
}
