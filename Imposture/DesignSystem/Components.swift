import SwiftUI

/// An icon-plus-text fact, e.g. duration or position. Never relies on the icon alone.
struct MetaLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .imageScale(.small)
        }
        .font(.subheadline)
        .foregroundStyle(Color.impostureTextSecondary)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thin separator in the brand line colour.
struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.impostureSeparator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A list row for an exercise, used in Library and routine details.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Spacing.md) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.impostureTextPrimary)
                Text(exercise.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.sm) { meta }
                    VStack(alignment: .leading, spacing: Spacing.xxs) { meta }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DisclosureChevron()
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var meta: some View {
        MetaLabel(text: DurationText.short(exercise.duration), systemImage: "clock")
        MetaLabel(text: exercise.position.title, systemImage: exercise.position.systemImage)
    }
}

/// A list row for a routine.
struct RoutineRow: View {
    let routine: Routine
    let plan: SessionPlan

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let first = plan.exercises.first {
                ExerciseThumbnail(exercise: first)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(routine.title)
                    .font(.headline)
                    .foregroundStyle(Color.impostureTextPrimary)
                Text(routine.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .lineLimit(2)
                MetaLabel(
                    text: "\(plan.roundedMinutes) min · \(plan.exercises.count) exercises",
                    systemImage: "clock"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DisclosureChevron()
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.impostureTextSecondary)
            .accessibilityHidden(true)
    }
}

/// A selectable row with a visible checkmark, so selection never depends on colour alone.
struct SelectableRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    /// Artwork shown instead of the symbol, e.g. the posture-strain figures for body areas.
    var imageName: String?
    let isSelected: Bool
    var isRadio = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let imageName, Artwork.showsIllustrations {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .frame(width: 32)
                        .foregroundStyle(Color.impostureTextPrimary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.impostureTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.impostureTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: indicatorSymbol)
                    .font(.title2)
                    .foregroundStyle(Color.impostureTextPrimary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(minHeight: TouchTarget.minimum)
            .background(
                isSelected ? Color.impostureAccentSoft : Color.impostureSurface,
                in: .rect(cornerRadius: Radius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(isSelected ? Color.impostureTextPrimary : Color.impostureSeparator, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var indicatorSymbol: String {
        if isRadio {
            isSelected ? "largecircle.fill.circle" : "circle"
        } else {
            isSelected ? "checkmark.circle.fill" : "circle"
        }
    }
}

/// A calm, non-alarming note for safety information.
struct NoteBox: View {
    let title: String
    let message: String
    var systemImage = "heart.text.square"

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.impostureTextPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(Color.impostureSurfaceEmphasis, in: .rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Empty, error and similar placeholder states.
struct StateMessage<Actions: View>: View {
    let title: String
    let message: String
    var imageName: String?
    var systemImage: String?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let imageName, Artwork.showsIllustrations {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.impostureTextSecondary)
                .multilineTextAlignment(.center)
            actions()
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}

extension StateMessage where Actions == EmptyView {
    init(title: String, message: String, imageName: String? = nil, systemImage: String? = nil) {
        self.init(title: title, message: message, imageName: imageName, systemImage: systemImage) { EmptyView() }
    }
}

enum DurationText {
    /// "45 sec", "1 min", "1 min 30 sec".
    static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let remainder = total % 60
        switch (minutes, remainder) {
        case (0, _): return "\(remainder) sec"
        case (_, 0): return "\(minutes) min"
        default: return "\(minutes) min \(remainder) sec"
        }
    }

    /// "0:45" style countdown.
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Spoken form for VoiceOver, e.g. "45 seconds remaining".
    static func spokenRemaining(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 60 ? [.minute, .second] : [.second]
        let value = formatter.string(from: TimeInterval(seconds)) ?? "\(seconds) seconds"
        return "\(value) remaining"
    }
}
