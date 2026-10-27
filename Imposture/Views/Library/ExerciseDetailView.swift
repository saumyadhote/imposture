import SwiftUI

/// Everything needed to understand one movement before trying it.
struct ExerciseDetailView: View {
    let exerciseID: String
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let exercise = appModel.library?.exercise(id: exerciseID) {
            content(for: exercise)
        } else {
            StateMessage(
                title: "Exercise not found",
                message: "This exercise isn't available any more.",
                systemImage: "questionmark.circle"
            )
            .frame(maxHeight: .infinity)
            .impostureScreenBackground()
        }
    }

    private func content(for exercise: Exercise) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                MascotDemo(exercise: exercise)
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(exercise.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.impostureTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(exercise.summary)
                        .font(.body)
                        .foregroundStyle(Color.impostureTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                FactsGrid(exercise: exercise)

                BrandDivider()

                if let startingPosition = exercise.startingPosition {
                    InfoSection(title: "Starting position", systemImage: "chair", text: startingPosition)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Follow along", subtitle: exercise.repsGuide)
                    NumberedSteps(steps: exercise.steps)
                }

                if let hold = exercise.hold {
                    InfoSection(title: "Hold", systemImage: "timer", text: hold)
                }

                if let switchSides = exercise.switchSides {
                    InfoSection(title: "Switch sides", systemImage: "arrow.left.and.right", text: switchSides)
                }

                if let feel = exercise.feel {
                    InfoSection(title: "What you should feel", systemImage: "hand.wave", text: feel)
                }

                if !exercise.easier.isEmpty {
                    BulletSection(title: "Make it easier", systemImage: "arrow.down.right.circle", items: exercise.easier)
                }

                if !exercise.cautions.isEmpty {
                    BulletSection(title: "Take care", systemImage: "hand.raised", items: exercise.cautions)
                }

                NoteBox(
                    title: "General guidance only",
                    message: "Move within a comfortable range. This is not medical advice. If you have an injury or health condition, check with a professional first."
                )
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.lg)
        }
        .impostureScreenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                appModel.start(SessionPlan(single: exercise))
            } label: {
                Label("Try it now · \(DurationText.short(exercise.duration))", systemImage: "play.fill")
            }
            .buttonStyle(.imposturePrimary)
            .accessibilityIdentifier("exercise.tryNow")
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
            .background(Color.impostureBackground)
        }
    }
}

private struct FactsGrid: View {
    let exercise: Exercise

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.md) { facts }
            VStack(alignment: .leading, spacing: Spacing.xs) { facts }
        }
    }

    @ViewBuilder private var facts: some View {
        MetaLabel(text: DurationText.short(exercise.duration), systemImage: "clock")
        MetaLabel(text: exercise.position.title, systemImage: exercise.position.systemImage)
        if let equipment = exercise.equipment.title {
            MetaLabel(text: equipment, systemImage: "checklist")
        }
        if exercise.bothSides {
            MetaLabel(text: "Both sides", systemImage: "arrow.left.and.right")
        }
    }
}

private struct InfoSection: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.impostureTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BulletSection: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("•")
                        .accessibilityHidden(true)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
                .foregroundStyle(Color.impostureTextPrimary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseID: "standing-hip-flexor-stretch")
    }
    .environment(AppModel.preview())
}
