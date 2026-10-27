import SwiftUI

/// "Your starting point": how much of what was measured sits within the guide ranges, then the
/// areas to focus on. The full measurements and notes sit behind the info button.
/// Only measured values appear; a skipped or empty scan says so instead of guessing.
struct BaselineResultsView: View {
    let assessment: BaselineAssessment
    var onBuildPlan: () -> Void

    @State private var isShowingDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Your starting point")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                GuideShareCard(assessment: assessment)
                focusAreas
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button("Build my plan", action: onBuildPlan)
                .buttonStyle(.imposturePrimary)
                .accessibilityIdentifier("onboarding.buildPlan")
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.sm)
                .background(AppTheme.background)
        }
        .sheet(isPresented: $isShowingDetails) {
            ScanDetailsSheet(assessment: assessment)
        }
    }

    // MARK: Areas to focus on

    private var focusAreas: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center) {
                Text("Areas to focus on")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    isShowingDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Scan details")
                .accessibilityIdentifier("onboarding.scanDetails")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                if areas.isEmpty {
                    Text("Nothing stood out. Your plan starts with a balanced mix.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(areas, id: \.title) { area in
                        AreaRow(area: area)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        }
    }

    /// What the scan found first, then any chosen areas it didn't already cover.
    private var areas: [Area] {
        var list = assessment.findings.map { Area(title: $0.title, detail: $0.detail, source: .scan) }
        let covered = Set(list.map { $0.title.lowercased() })
        for focus in FocusArea.allCases where assessment.selectedFocusAreas.contains(focus) {
            guard !covered.contains(focus.title.lowercased()) else { continue }
            list.append(Area(title: focus.title, detail: focus.description, source: .choice))
        }
        return list
    }
}

// MARK: - Pieces

private struct Area {
    enum Source { case scan, choice }
    let title: String
    let detail: String
    let source: Source
}

private struct AreaRow: View {
    let area: Area

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(area.source == .scan ? AppTheme.limeAccent : Color.impostureGreenDeep)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(area.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(area.source == .scan ? "From your scan" : "You chose this")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text(area.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The percentage of measurements within their guide ranges, as a bar.
/// With nothing measured it says so and draws no bar, so it never reads as 0%.
private struct GuideShareCard: View {
    let assessment: BaselineAssessment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let share = assessment.withinGuideShare {
                HStack(alignment: .firstTextBaseline) {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("\(assessment.withinGuideCount) of \(assessment.clinicalMetrics.count) within guide")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Capsule()
                    .fill(AppTheme.surfaceEmphasis)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(BrandGradient.primary)
                                .frame(width: max(proxy.size.width * share * shown, share > 0 ? 8 : 0))
                        }
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)
                Text("of your measurements sit within the guide ranges.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("No measurements yet")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(assessment.isScanCompleted
                     ? "The scan couldn't measure anything clearly. Your plan starts from the areas you chose."
                     : "You skipped the body scan. Your plan starts from the areas you chose, and you can check your posture any time from the Posture tab.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandGradient.card, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.15)) { shown = 1 }
        }
    }
}

/// The supporting detail: every measurement, how much was captured, and the caveats.
private struct ScanDetailsSheet: View {
    let assessment: BaselineAssessment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if assessment.hasMeasurements {
                    Section("Measurements") {
                        ForEach(assessment.clinicalMetrics) { metric in
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(metric.name)
                                        .font(.headline)
                                    Spacer(minLength: Spacing.sm)
                                    Text(metric.measuredValue)
                                        .font(.headline)
                                        .monospacedDigit()
                                }
                                Text("Guide \(metric.normativeRange) · \(metric.status.rawValue)")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(metric.justification)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, Spacing.xxs)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Section("Scan") {
                        LabeledContent("Frames captured", value: "\(assessment.capturedFrames)")
                    }
                } else {
                    Section {
                        Text(assessment.isScanCompleted ? "The scan didn't capture anything it could measure." : "The body scan was skipped, so there are no measurements.")
                    }
                }
                Section {
                    Text("These are estimates from your phone camera to guide your plan. They aren't a medical assessment. The percentage counts measurements within their guide ranges; it isn't a posture score.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Scan details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Skipped") {
    BaselineResultsView(assessment: .skipped(focus: [.techNeck]), onBuildPlan: {})
}

#Preview("Measured") {
    BaselineResultsView(
        assessment: BaselineAssessment(
            selectedFocusAreas: [.techNeck, .roundedShoulders],
            findings: [PostureFinding(title: "Tech neck", detail: "Your head sits forward of your shoulders (47° neck angle).")],
            clinicalMetrics: [
                ClinicalMetric(name: "Neck angle (CVA)", measuredValue: "47.0°", normativeRange: "≥ 52°", status: .attention, justification: "From your side view."),
                ClinicalMetric(name: "Shoulder level", measuredValue: "1.2° tilt", normativeRange: "< 2.5°", status: .optimal, justification: "From the front view."),
            ],
            capturedFrames: 20,
            isScanCompleted: true
        ),
        onBuildPlan: {}
    )
}
