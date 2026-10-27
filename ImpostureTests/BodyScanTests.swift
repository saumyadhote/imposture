import CoreGraphics
import Foundation
import Testing
@testable import Imposture

struct BodyScanAnalysisTests {
    private let front = PostureLandmarks(
        nose: CGPoint(x: 0.5, y: 0.74), neck: CGPoint(x: 0.5, y: 0.6),
        leftEar: CGPoint(x: 0.44, y: 0.75), rightEar: CGPoint(x: 0.56, y: 0.75),
        leftShoulder: CGPoint(x: 0.36, y: 0.58), rightShoulder: CGPoint(x: 0.64, y: 0.62),
        leftHip: CGPoint(x: 0.42, y: 0.28), rightHip: CGPoint(x: 0.58, y: 0.28)
    )

    @Test("a skipped scan claims nothing, whatever was chosen")
    func skipped() {
        let assessment = BaselineAssessment.skipped(focus: [.techNeck, .roundedShoulders])
        #expect(assessment.findings.isEmpty)
        #expect(assessment.clinicalMetrics.isEmpty)
        #expect(!assessment.hasMeasurements)
        #expect(!assessment.isScanCompleted)
    }

    @Test("without a side view there is no neck angle, head load or tech-neck finding")
    func frontOnly() {
        let data = MultiAngleScanData(front: front, frontFrames: Array(repeating: front, count: 5))
        let assessment = BaselineAssessment.generate(from: [.techNeck, .hunchBack], scanData: data)
        #expect(assessment.cvaAngle == nil)
        #expect(!assessment.clinicalMetrics.contains { $0.name.contains("Neck angle") || $0.name.contains("head load") })
        #expect(!assessment.findings.contains { $0.title == "Tech neck" }, "Choosing a focus area doesn't create a finding")
        #expect(assessment.shoulderTiltAngle != nil, "The front view does measure shoulder level")
        #expect(assessment.capturedFrames == 5)
    }

    @Test("nothing captured means no measurements at all")
    func empty() {
        let assessment = BaselineAssessment.generate(from: [.techNeck], scanData: MultiAngleScanData())
        #expect(!assessment.hasMeasurements)
        #expect(assessment.findings.isEmpty)
    }

    @Test("the percentage counts measurements within guide, and is absent with none")
    func withinGuideShare() {
        #expect(BaselineAssessment.skipped(focus: [.techNeck]).withinGuideShare == nil)
        let metrics = [
            ClinicalMetric(name: "A", measuredValue: "1", normativeRange: "", status: .optimal, justification: ""),
            ClinicalMetric(name: "B", measuredValue: "2", normativeRange: "", status: .attention, justification: ""),
            ClinicalMetric(name: "C", measuredValue: "3", normativeRange: "", status: .optimal, justification: ""),
            ClinicalMetric(name: "D", measuredValue: "4", normativeRange: "", status: .severe, justification: ""),
        ]
        let assessment = BaselineAssessment(clinicalMetrics: metrics, isScanCompleted: true)
        #expect(assessment.withinGuideCount == 2)
        #expect(assessment.withinGuideShare == 0.5)
    }

    @Test("focus areas map onto the app's concerns")
    func mapping() {
        #expect(Set(FocusArea.allCases.map(\.bodyArea)) == Set(BodyArea.concerns))
    }
}
