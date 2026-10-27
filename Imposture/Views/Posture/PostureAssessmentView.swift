import SwiftUI

/// The Posture tab: what the assessment is, a clear way to begin, and past results.
/// The camera only starts inside the assessment flow, never on this screen.
struct PostureAssessmentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isAssessing = false
    @State private var path = NavigationPath()
    /// A programme day chosen from a report inside the full-screen flow.
    @State private var routeAfterFlow: PostureRoute?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    intro
                    history
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.impostureDashboardBackground.ignoresSafeArea())
            .navigationTitle("Posture")
            .navigationDestination(for: PostureRoute.self) { route in
                switch route {
                case .report(let id): StoredReportView(assessmentID: id) { path.append(PostureRoute.routine($0.id)) }
                case .routine(let id): RoutineDetailView(routineID: id)
                case .score(let day): PostureScoreView(day: day)
                }
            }
            .navigationDestination(for: PostureCheckStep.self) { step in
                PostureCheckStepView(step: step) { advance(from: step) }
            }
            .appRouteDestinations()
        }
        .fullScreenCover(isPresented: $isAssessing, onDismiss: openRouteAfterFlow) {
            PostureAssessmentFlow { routine in
                routeAfterFlow = .routine(routine.id)
                isAssessing = false
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuroraOrb(size: 160)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Seated posture check")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.impostureDashboardText)
                Text("Prop your iPhone to your side and carry on working. imposture estimates how your head and upper body sit, for up to ten minutes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                begin()
            } label: {
                Label("Begin assessment", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.imposturePrimary)
            .accessibilityIdentifier("posture.begin")
            Label("Analysed on this iPhone. No photos or video are saved.", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Preparation

    private func begin() {
        guard path.isEmpty else { return }
        path.append(PostureCheckStep.prepare)
    }

    /// Pushes the next step, or opens the camera check after the last one.
    /// Only the step on top can advance, so a double tap never pushes twice.
    private func advance(from step: PostureCheckStep) {
        guard path.count == step.rawValue + 1 else { return }
        if let next = step.next {
            path.append(next)
        } else if !isAssessing {
            isAssessing = true
        }
    }

    @ViewBuilder private var history: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Previous results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .accessibilityAddTraits(.isHeader)
            if let error = appModel.assessmentsError {
                NoteBox(title: "Results unavailable", message: error, systemImage: "exclamationmark.triangle")
            } else if appModel.assessments.isEmpty {
                Text("Your results will appear here after your first assessment.")
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
            } else {
                ForEach(appModel.assessments) { assessment in
                    NavigationLink(value: PostureRoute.report(assessment.id)) {
                        AssessmentRow(assessment: assessment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openRouteAfterFlow() {
        // The preparation steps are done with once the check has run.
        path = NavigationPath()
        guard let route = routeAfterFlow else { return }
        routeAfterFlow = nil
        path.append(route)
    }
}

enum PostureRoute: Hashable {
    case report(UUID)
    case routine(String)
    /// The Posture Score screen, opened on this day.
    case score(Date)
}

/// One past assessment in a list.
struct AssessmentRow: View {
    let assessment: PostureAssessment

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(assessment.endedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(Color.impostureTextPrimary)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DisclosureChevron()
        }
        .padding(Spacing.md)
        .background(Color.impostureSurface.opacity(0.8), in: .rect(cornerRadius: Radius.control, style: .continuous))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        var parts = [DurationText.short(assessment.activeSeconds)]
        if let head = assessment.headForwardMedian {
            parts.append("head \(Int(head.rounded()))° forward")
        }
        return parts.joined(separator: " · ")
    }
}

/// A saved report, compared with the assessment before it.
struct StoredReportView: View {
    let assessmentID: UUID
    let onOpenRecommended: (Routine) -> Void
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = ProgressViewModel()

    var body: some View {
        if let assessment = appModel.assessments.first(where: { $0.id == assessmentID }) {
            ScrollView {
                PostureReportView(
                    analysis: viewModel.analysis(for: assessment, in: appModel.assessments),
                    recommended: appModel.recommendedDay(for: assessment),
                    onOpenRecommended: onOpenRecommended
                )
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
            }
            .impostureScreenBackground()
            .navigationTitle("Posture report")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Result not found", systemImage: "questionmark.circle")
                .impostureScreenBackground()
        }
    }
}

#Preview {
    PostureAssessmentView()
        .environment(AppModel.preview())
}
