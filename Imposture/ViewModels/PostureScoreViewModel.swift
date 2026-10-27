import Foundation
import Observation

/// What one day's posture data supports. Only measured values appear; anything the app
/// doesn't track yet stays nil so it can never be shown as zero.
struct PostureDaySummary: Equatable {
    let day: Date
    /// Assessments that day that measured the head.
    let checks: [PostureAssessment]
    /// Share of measured time the head stayed within the guide angle, weighted by usable frames.
    let postureRange: Double?
    /// Guided sessions completed that day, or nil when history couldn't be loaded.
    let completedSessions: Int?

    /// A score out of 100 needs a validated method that combines posture, movement and sitting
    /// time. None is implemented, so there is never a score to show.
    var score: Int? { nil }
    /// Long uninterrupted sits need sitting-time tracking, which the app doesn't have.
    var longSits: Int? { nil }

    var hasPostureData: Bool { postureRange != nil }

    init(day: Date, assessments: [PostureAssessment], history: [CompletedSession]?, calendar: Calendar) {
        self.day = calendar.startOfDay(for: day)
        let checks = assessments.filter { $0.headForwardShare != nil && calendar.isDate($0.endedAt, inSameDayAs: day) }
        self.checks = checks.sorted { $0.endedAt > $1.endedAt }

        let frames = checks.reduce(0) { $0 + $1.headFrames }
        if frames > 0 {
            let inRange = checks.reduce(0.0) { (total: Double, check: PostureAssessment) -> Double in
                let share = 1 - (check.headForwardShare ?? 0)
                return total + share * Double(check.headFrames)
            }
            postureRange = inRange / Double(frames)
        } else {
            postureRange = nil
        }
        completedSessions = history.map { sessions in
            sessions.filter { $0.completesRoutine && calendar.isDate($0.endedAt, inSameDayAs: day) }.count
        }
    }
}

/// The Posture Score screen: which day is shown, and moving between days.
@MainActor @Observable
final class PostureScoreViewModel {
    private(set) var day: Date

    private let now: () -> Date
    private let calendar: Calendar

    init(day: Date, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
        // Never start on a day that hasn't happened.
        self.day = calendar.startOfDay(for: min(day, now()))
    }

    var canGoForward: Bool { day < calendar.startOfDay(for: now()) }

    func goBack() {
        if let previous = calendar.date(byAdding: .day, value: -1, to: day) { day = previous }
    }

    func goForward() {
        guard canGoForward, let next = calendar.date(byAdding: .day, value: 1, to: day) else { return }
        day = next
    }

    func summary(assessments: [PostureAssessment], history: [CompletedSession], historyError: String?) -> PostureDaySummary {
        let knownHistory = historyError == nil || !history.isEmpty ? history : nil
        return PostureDaySummary(day: day, assessments: assessments, history: knownHistory, calendar: calendar)
    }

    /// "Today, 27 Oct", "Yesterday, 26 Oct" or "Mon, 20 Oct".
    var heading: String {
        let date = day.formatted(.dateTime.day().month(.abbreviated))
        let today = calendar.startOfDay(for: now())
        if day == today { return "Today, \(date)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday { return "Yesterday, \(date)" }
        return "\(day.formatted(.dateTime.weekday(.abbreviated))), \(date)"
    }
}
