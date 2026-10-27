import SwiftUI

/// Posture Score for one day: what was measured, what isn't tracked yet, and how it all works.
/// Never shows a made-up score: the app has no validated scoring method, so the score stays empty.
struct PostureScoreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: PostureScoreViewModel
    @State private var isShowingInfo = false

    init(day: Date) {
        _viewModel = State(initialValue: PostureScoreViewModel(day: day))
    }

    var body: some View {
        let summary = viewModel.summary(
            assessments: appModel.assessments,
            history: appModel.history,
            historyError: appModel.historyError
        )
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                dateBar
                if let error = appModel.assessmentsError, appModel.assessments.isEmpty {
                    errorCard(error)
                }
                scoreCard(summary)
                checks(summary)
                rhythmButton
                about
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.xl)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: viewModel.day)
        }
        .background(Color.impostureDashboardBackground.ignoresSafeArea())
        .navigationTitle("Posture Score")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: viewModel.day)
    }

    // MARK: Date

    private var dateBar: some View {
        HStack(spacing: Spacing.sm) {
            Text(viewModel.heading)
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            CircleIconButton(systemImage: "chevron.left", label: "Previous day", action: viewModel.goBack)
            CircleIconButton(systemImage: "chevron.right", label: "Next day", action: viewModel.goForward)
                .disabled(!viewModel.canGoForward)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: Score

    private func scoreCard(_ summary: PostureDaySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .center, spacing: Spacing.lg) {
                ScoreRing(progress: summary.score.map { Double($0) / 100 }, size: 132) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(summary.score.map(String.init) ?? "—")
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(summary.score == nil ? Color.impostureDashboardTextSecondary : Color.impostureDashboardText)
                        Text("/100")
                            .font(.footnote)
                            .foregroundStyle(Color.impostureDashboardTextSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(summary.score.map { "Score \($0) out of 100" } ?? "No score")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .top) {
                        Text(summary.hasPostureData ? "Not scored yet" : "Not enough data")
                            .font(.headline)
                            .foregroundStyle(Color.impostureDashboardText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            isShowingInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.body)
                                .foregroundStyle(Color.impostureDashboardTextSecondary)
                                .frame(width: TouchTarget.minimum, height: TouchTarget.minimum, alignment: .topTrailing)
                        }
                        .accessibilityLabel("How the score works")
                        .popover(isPresented: $isShowingInfo) {
                            Text(Self.scoreNote)
                                .font(.subheadline)
                                .foregroundStyle(Color.impostureDashboardText)
                                .padding(Spacing.md)
                                .frame(idealWidth: 300)
                                .fixedSize(horizontal: false, vertical: true)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                    Text(summary.hasPostureData
                         ? "A score needs a validated method. Your measured results are below."
                         : "Take a posture check on this day to see your posture range.")
                        .font(.subheadline)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                BreakdownRow(
                    title: "Posture Range",
                    detail: "Time in target range",
                    value: summary.postureRange.map { $0.formatted(.percent.precision(.fractionLength(0))) },
                    missing: "No check",
                    dot: .impostureAccentFill
                )
                divider
                BreakdownRow(
                    title: "Movement",
                    detail: "Guided sessions completed",
                    value: summary.completedSessions.map(String.init),
                    missing: "Unavailable",
                    dot: .impostureGreenLight
                )
                divider
                BreakdownRow(
                    title: "Long Sits",
                    detail: "Sitting time isn't tracked yet",
                    value: summary.longSits.map(String.init),
                    missing: "—",
                    dot: .impostureGreenDeep
                )
            }
        }
        .padding(Spacing.lg)
        .background(BrandGradient.card, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.impostureDashboardElevated)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    /// That day's checks, each opening its full report.
    @ViewBuilder private func checks(_ summary: PostureDaySummary) -> some View {
        if !summary.checks.isEmpty {
            VStack(spacing: 0) {
                ForEach(summary.checks) { check in
                    NavigationLink(value: PostureRoute.report(check.id)) {
                        HStack {
                            Label("Check at \(check.endedAt.formatted(date: .omitted, time: .shortened))", systemImage: "figure.seated.side.right")
                                .foregroundStyle(Color.impostureDashboardText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.impostureDashboardTextSecondary)
                        }
                        .font(.subheadline)
                        .frame(minHeight: TouchTarget.minimum)
                        .padding(.horizontal, Spacing.md)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        }
    }

    // MARK: Rhythm

    /// The Rhythm screen doesn't exist yet, so the entry point is shown but clearly disabled.
    private var rhythmButton: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {} label: {
                Label("View in Rhythm", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.impostureDashboardCard, in: .capsule)
            }
            .foregroundStyle(Color.impostureAccentFill.opacity(0.45))
            .disabled(true)
            .accessibilityHint("Rhythm isn't available yet")
            Text("Rhythm isn't available yet.")
                .font(.footnote)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: About

    private var about: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About Posture Score")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("How it's calculated")
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                Text(Self.scoreNote)
                Text("Posture range comes from your camera checks: the share of analysed time your ear stayed within \(Int(PostureThresholds.headForward))° of upright over your shoulder. Movement counts the guided sessions you finished that day.")
                Text("Long sits need sitting-time tracking, which isn't built yet.")
            }
            .font(.subheadline)
            .foregroundStyle(Color.impostureDashboardTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        }
    }

    private static let scoreNote = "A score out of 100 will combine time in a comfortable posture range, movement breaks and long sits. It isn't calculated yet because the method still needs validating, so no score is shown."

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.impostureGreenLight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardText)
                Button("Try again", action: appModel.reloadAssessments)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.impostureAccentFill)
                    .frame(minHeight: TouchTarget.minimum)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }
}

/// One line of the breakdown: a coloured key, the label and what it means, and the value.
private struct BreakdownRow: View {
    let title: String
    let detail: String
    let value: String?
    let missing: String
    let dot: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Text(value ?? missing)
                .font(value == nil ? .subheadline : .title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(value == nil ? Color.impostureDashboardTextSecondary : Color.impostureDashboardText)
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        PostureScoreView(day: .now)
    }
    .environment(AppModel.preview())
}
