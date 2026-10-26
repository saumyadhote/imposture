import Foundation
import Observation

/// State for the Progress screen: where its numbers come from.
@MainActor @Observable
final class ProgressViewModel {
    /// True shows example stats (previews only); false builds the dashboard from real history.
    let usesSampleData: Bool

    private let now: () -> Date

    init(usesSampleData: Bool = false, now: @escaping () -> Date = Date.init) {
        self.usesSampleData = usesSampleData
        self.now = now
    }

    func dashboard(history: [CompletedSession], assessments: [PostureAssessment]) -> ProgressDashboard {
        if usesSampleData {
            return .sample(period: .week, now: now())
        }
        return ProgressDashboard(
            history: history,
            postureReportDates: assessments.map(\.endedAt),
            period: .week,
            now: now()
        )
    }

    /// The report for an assessment, compared with the one before it.
    func analysis(for assessment: PostureAssessment, in assessments: [PostureAssessment]) -> PostureAnalysis {
        let older = assessments.filter { $0.endedAt < assessment.endedAt }.max { $0.endedAt < $1.endedAt }
        return PostureAnalysis(assessment, previous: older)
    }
}
