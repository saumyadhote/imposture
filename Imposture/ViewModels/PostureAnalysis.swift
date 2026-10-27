import Foundation

/// The readable report for one posture assessment: what could be measured, what couldn't,
/// and how it compares with the previous one. Built only from real measurements.
struct PostureAnalysis: Equatable {
    enum Reliability: Equatable {
        case measured
        case notAssessed

        var title: String {
            switch self {
            case .measured: "Measured"
            case .notAssessed: "Not assessed"
            }
        }
    }

    /// How a finding compares with the previous assessment.
    enum Trend: Equatable {
        case better(String)
        case unchanged(String)
        case worse(String)
    }

    struct Finding: Identifiable, Equatable {
        let title: String
        let detail: String
        let trend: Trend?
        let reliability: Reliability
        var id: String { title }
    }

    let assessment: PostureAssessment
    let findings: [Finding]
    let comparedWithPrevious: Bool

    /// "Good" once most of the assessment showed the head and shoulder clearly.
    var observationQuality: String {
        switch assessment.visibleShare {
        case 0.8...: "Good"
        case 0.5..<0.8: "Fair"
        default: "Low"
        }
    }

    init(_ assessment: PostureAssessment, previous: PostureAssessment? = nil) {
        self.assessment = assessment
        comparedWithPrevious = previous?.hasFindings == true
        findings = [
            Self.headFinding(assessment, previous: previous),
            Finding(
                title: "Shoulder alignment",
                detail: "A side view can't show whether your shoulders are level or rounded.",
                trend: nil,
                reliability: .notAssessed
            ),
            Self.trunkFinding(assessment, previous: previous),
        ]
    }

    private static func headFinding(_ a: PostureAssessment, previous: PostureAssessment?) -> Finding {
        guard let median = a.headForwardMedian, let share = a.headForwardShare else {
            return Finding(title: "Head and neck", detail: "Your ear and shoulder weren't clear enough to measure.", trend: nil, reliability: .notAssessed)
        }
        return Finding(
            title: "Head and neck",
            detail: "Ear typically \(degrees(median)) ahead of your shoulder · beyond \(degrees(PostureThresholds.headForward)) for \(percent(share)) of the time",
            trend: trend(now: median, before: previous?.headForwardMedian),
            reliability: .measured
        )
    }

    private static func trunkFinding(_ a: PostureAssessment, previous: PostureAssessment?) -> Finding {
        guard let median = a.trunkLeanMedian, let share = a.trunkLeanShare else {
            return Finding(title: "Upper-body lean", detail: "Your shoulder and hip weren't clear enough to measure.", trend: nil, reliability: .notAssessed)
        }
        let direction = median >= 0 ? "forward" : "back"
        return Finding(
            title: "Upper-body lean",
            detail: "Typically \(degrees(abs(median))) \(direction) from upright · beyond \(degrees(PostureThresholds.trunkLean)) forward for \(percent(share)) of the time",
            trend: trend(now: median, before: previous?.trunkLeanMedian),
            reliability: .measured
        )
    }

    /// Smaller forward angles read as better. Changes under 3° count as unchanged,
    /// since the estimate itself varies by about that much.
    private static func trend(now: Double, before: Double?) -> Trend? {
        guard let before else { return nil }
        let change = now - before
        if abs(change) < 3 { return .unchanged("About the same as last time") }
        return change < 0
            ? .better("\(degrees(abs(change))) less than last time")
            : .worse("\(degrees(change)) more than last time")
    }

    private static func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

#if DEBUG
extension PostureAssessment {
    /// Example values for previews only. Never shown in the running app.
    static func previewSample(now: Date = .now) -> PostureAssessment {
        PostureAssessment(
            id: UUID(),
            startedAt: now.addingTimeInterval(-600),
            endedAt: now,
            activeSeconds: 600,
            framesAnalysed: 590,
            headFrames: 520,
            trunkFrames: 480,
            headForwardMedian: 22,
            headForwardShare: 0.56,
            trunkLeanMedian: 9,
            trunkLeanShare: 0.18
        )
    }
}
#endif
