import SwiftUI

/// A posture assessment report: how much was seen, what was measured, what wasn't,
/// and a suggested day from the programme.
struct PostureReportView: View {
    let analysis: PostureAnalysis
    /// A programme day suited to the findings, if any.
    var recommended: Routine?
    var onOpenRecommended: ((Routine) -> Void)?

    private var assessment: PostureAssessment { analysis.assessment }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(heading)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.impostureTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subheading)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
            }

            ReportSection(title: "Observation") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Clearly in view")
                        .font(.headline)
                        .foregroundStyle(Color.impostureTextPrimary)
                    Spacer()
                    Text(analysis.observationQuality)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(assessment.visibleShare >= 0.8 ? Color.impostureGreenLight : Color.impostureTextSecondary)
                }
                ProgressView(value: assessment.visibleShare)
                    .tint(Color.impostureAccentFill)
                    .accessibilityHidden(true)
                Text("Head and shoulder visible in \(assessment.headFrames) of \(assessment.framesAnalysed) analysed frames")
                    .font(.footnote)
                    .foregroundStyle(Color.impostureTextSecondary)
            }
            .accessibilityElement(children: .combine)

            ReportSection(title: "What we measured") {
                ForEach(analysis.findings) { finding in
                    FindingRow(finding: finding)
                    if finding.id != analysis.findings.last?.id {
                        BrandDivider()
                    }
                }
            }

            if let recommended {
                ReportSection(title: "Suggested session") {
                    Button {
                        onOpenRecommended?(recommended)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(recommended.day ?? 0)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.impostureAccentText)
                                Text(recommended.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.impostureTextPrimary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            DisclosureChevron()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(onOpenRecommended == nil)
                    .accessibilityIdentifier("report.recommended")
                }
            }

            Text("Estimated on this iPhone from a 2D side view. Camera angle and lighting affect the numbers. This is a general guide, not a medical assessment.")
                .font(.footnote)
                .foregroundStyle(Color.impostureTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heading: String {
        let time = assessment.endedAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(assessment.endedAt) { return "Today, \(time)" }
        return "\(assessment.endedAt.formatted(.dateTime.day().month())), \(time)"
    }

    private var subheading: String {
        let length = DurationText.short(assessment.activeSeconds)
        return analysis.comparedWithPrevious ? "\(length) assessment · compared with your last one" : "\(length) assessment"
    }
}

private struct ReportSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.impostureTextSecondary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                content
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.impostureSurface.opacity(0.8), in: .rect(cornerRadius: Radius.control, style: .continuous))
        }
    }
}

private struct FindingRow: View {
    let finding: PostureAnalysis.Finding

    private var measured: Bool { finding.reliability == .measured }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(finding.title)
                    .font(.headline)
                    .foregroundStyle(measured ? Color.impostureTextPrimary : Color.impostureTextSecondary)
                Spacer()
                Text(finding.reliability.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.impostureTextSecondary)
            }
            Text(finding.detail)
                .font(.subheadline)
                .foregroundStyle(Color.impostureTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let trend = finding.trend {
                trendText(trend)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func trendText(_ trend: PostureAnalysis.Trend) -> some View {
        switch trend {
        case .better(let text):
            Label(text, systemImage: "arrow.down.right")
                .foregroundStyle(Color.impostureGreenLight)
        case .worse(let text):
            Label(text, systemImage: "arrow.up.right")
                .foregroundStyle(Color.impostureTextPrimary)
        case .unchanged(let text):
            Text(text)
                .foregroundStyle(Color.impostureTextSecondary)
        }
    }
}

#if DEBUG
#Preview {
    ScrollView {
        PostureReportView(analysis: PostureAnalysis(.previewSample()))
            .padding()
    }
    .impostureScreenBackground()
}
#endif
