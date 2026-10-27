import SwiftUI

/// A gentle suggestion for someone starting another programme day after finishing one today.
/// A recommendation, not a warning: they can start recovery, continue, or swipe it away.
struct RecoverySheet: View {
    let offer: RecoveryOffer
    @Environment(AppModel.self) private var appModel
    @State private var selectedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "leaf")
                        .font(.title2)
                        .foregroundStyle(Color.impostureSecondaryAccent)
                        .accessibilityHidden(true)
                    Text("You've completed today's session.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.impostureTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your programme is designed to progress over time. If you'd like to keep moving, try a gentle mobility session instead.")
                        .font(.body)
                        .foregroundStyle(Color.impostureTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Spacing.sm) {
                    ForEach(offer.alternatives) { routine in
                        if let plan = appModel.plan(for: routine) {
                            SelectableRow(
                                title: routine.title,
                                subtitle: "\(plan.roundedMinutes) min · \(plan.exercises.count) exercises",
                                systemImage: routine.id == Routine.deskResetID ? "chair.lounge" : "figure.flexibility",
                                isSelected: selected?.id == routine.id,
                                isRadio: true
                            ) {
                                selectedID = routine.id
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                Button("Start Recovery") {
                    if let selected { appModel.chooseFromRecoveryOffer(selected) }
                }
                .buttonStyle(.imposturePrimary)
                .disabled(selected == nil)
                .accessibilityIdentifier("recovery.start")

                Button("Continue to Day \(offer.requested.day ?? 0)") {
                    appModel.chooseFromRecoveryOffer(offer.requested)
                }
                .font(.headline)
                .foregroundStyle(Color.impostureTextPrimary)
                .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
                .accessibilityIdentifier("recovery.continue")
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.impostureBackground)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    /// Gentle Mobility unless the person picked something else.
    private var selected: Routine? {
        offer.alternatives.first { $0.id == selectedID } ?? offer.alternatives.first
    }
}
