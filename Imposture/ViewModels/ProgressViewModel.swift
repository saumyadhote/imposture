import Foundation
import Observation

/// One figure on the Progress screen, ready to display. `isKnown` is false when the
/// figure can't be counted (for example, history failed to load), so it shows "—" not 0.
struct MetricReading: Equatable {
    let value: String
    var unit: String?
    let detail: String
    var isKnown = true

    static func unknown(_ detail: String) -> MetricReading {
        MetricReading(value: "—", detail: detail, isKnown: false)
    }
}

/// What the posture card can honestly show for the selected period.
enum PostureCardState: Equatable {
    /// The latest measured assessment, and the share of it spent within the guide angle.
    case measured(PostureAssessment, inRange: Double, measure: String)
    /// No measured assessment in the period.
    case notEnoughData
    /// No assessment in the period, and the camera can't be used to take one.
    case cameraDenied
    /// Assessments couldn't be loaded and none are cached.
    case unavailable(String)
}

/// State for the Progress screen: the selected period and where its numbers come from.
@MainActor @Observable
final class ProgressViewModel {
    var period: ProgressPeriod = .thisWeek
    /// Read when the screen appears; nil until then.
    private(set) var cameraAccess: CameraAccess?

    /// True shows example stats (previews only); false builds the dashboard from real history.
    let usesSampleData: Bool

    private let now: () -> Date
    private let calendar: Calendar
    private let readCameraAccess: () -> CameraAccess

    init(
        usesSampleData: Bool = false,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        cameraAccess: @escaping () -> CameraAccess = { CameraService().access }
    ) {
        self.usesSampleData = usesSampleData
        self.now = now
        self.calendar = calendar
        readCameraAccess = cameraAccess
    }

    func refreshCameraAccess() {
        cameraAccess = readCameraAccess()
    }

    func dashboard(history: [CompletedSession], assessments: [PostureAssessment]) -> ProgressDashboard {
        if usesSampleData {
            return .sample(period: period, now: now(), calendar: calendar)
        }
        return ProgressDashboard(history: history, assessments: assessments, period: period, now: now(), calendar: calendar)
    }

    /// True when nothing has ever been recorded and nothing failed to load.
    func hasNoData(history: [CompletedSession], assessments: [PostureAssessment], errors: [String?]) -> Bool {
        !usesSampleData && history.isEmpty && assessments.isEmpty && errors.allSatisfy { $0 == nil }
    }

    // MARK: Readings

    /// History is usable when it loaded, or when an earlier load is still held.
    private func isKnown(_ items: some Collection, error: String?) -> Bool {
        usesSampleData || error == nil || !items.isEmpty
    }

    func sessions(_ dashboard: ProgressDashboard, history: [CompletedSession], error: String?) -> MetricReading {
        guard isKnown(history, error: error) else { return .unknown("Sessions couldn't be loaded") }
        return MetricReading(value: "\(dashboard.completedSessions)", detail: "Completed \(periodPhrase)")
    }

    func exerciseTime(_ dashboard: ProgressDashboard, history: [CompletedSession], error: String?) -> MetricReading {
        guard isKnown(history, error: error) else { return .unknown("Time couldn't be loaded") }
        let minutes = dashboard.minutes
        if minutes >= 60 {
            let rest = minutes % 60
            return MetricReading(value: "\(minutes / 60)", unit: rest == 0 ? "h" : "h \(rest) min", detail: "Active time \(periodPhrase)")
        }
        return MetricReading(value: "\(minutes)", unit: "min", detail: "Active time \(periodPhrase)")
    }

    func consistency(_ dashboard: ProgressDashboard, history: [CompletedSession], error: String?) -> MetricReading {
        guard isKnown(history, error: error) else { return .unknown("Couldn't be worked out") }
        guard let share = dashboard.consistency else { return .unknown("No tracked days yet") }
        return MetricReading(
            value: "\(Int((share * 100).rounded()))",
            unit: "%",
            detail: "\(dashboard.activeDays) of \(days(dashboard.trackingDays)) with a routine"
        )
    }

    func trackingDays(
        _ dashboard: ProgressDashboard,
        history: [CompletedSession], historyError: String?,
        assessments: [PostureAssessment], assessmentsError: String?
    ) -> MetricReading {
        guard isKnown(history, error: historyError), isKnown(assessments, error: assessmentsError) else {
            return .unknown("Couldn't be counted")
        }
        let total = dashboard.days.count { !$0.isFuture }
        return MetricReading(
            value: "\(dashboard.trackingDays)",
            unit: dashboard.trackingDays == 1 ? "day" : "days",
            detail: "Of \(days(total)) so far"
        )
    }

    func posture(_ dashboard: ProgressDashboard, assessments: [PostureAssessment], error: String?) -> PostureCardState {
        if let latest = dashboard.latestAssessment {
            if let share = latest.headForwardShare {
                return .measured(latest, inRange: 1 - share, measure: "Head within guide angle")
            }
            if let share = latest.trunkLeanShare {
                return .measured(latest, inRange: 1 - share, measure: "Upper body within guide angle")
            }
        }
        if !isKnown(assessments, error: error), let error { return .unavailable(error) }
        if cameraAccess == .denied { return .cameraDenied }
        return .notEnoughData
    }

    private var periodPhrase: String {
        switch period {
        case .today: "today"
        case .thisWeek: "this week"
        case .last30Days: "in 30 days"
        }
    }

    private func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    /// The report for an assessment, compared with the one before it.
    func analysis(for assessment: PostureAssessment, in assessments: [PostureAssessment]) -> PostureAnalysis {
        let older = assessments.filter { $0.endedAt < assessment.endedAt }.max { $0.endedAt < $1.endedAt }
        return PostureAnalysis(assessment, previous: older)
    }
}
