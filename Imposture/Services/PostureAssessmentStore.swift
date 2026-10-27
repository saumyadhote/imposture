import Foundation
import SwiftData

protocol PostureAssessmentStoring {
    func fetchAll() throws -> [PostureAssessment]
    func add(_ assessment: PostureAssessment) throws
    func deleteAll() throws
}

/// Stored measurements only. There is no image, video or joint data in here.
@Model
final class PostureAssessmentEntity {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var activeSeconds: Double
    var framesAnalysed: Int
    var headFrames: Int
    var trunkFrames: Int
    var headForwardMedian: Double?
    var headForwardShare: Double?
    var trunkLeanMedian: Double?
    var trunkLeanShare: Double?

    init(_ assessment: PostureAssessment) {
        id = assessment.id
        startedAt = assessment.startedAt
        endedAt = assessment.endedAt
        activeSeconds = assessment.activeSeconds
        framesAnalysed = assessment.framesAnalysed
        headFrames = assessment.headFrames
        trunkFrames = assessment.trunkFrames
        headForwardMedian = assessment.headForwardMedian
        headForwardShare = assessment.headForwardShare
        trunkLeanMedian = assessment.trunkLeanMedian
        trunkLeanShare = assessment.trunkLeanShare
    }

    var value: PostureAssessment {
        PostureAssessment(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            framesAnalysed: framesAnalysed,
            headFrames: headFrames,
            trunkFrames: trunkFrames,
            headForwardMedian: headForwardMedian,
            headForwardShare: headForwardShare,
            trunkLeanMedian: trunkLeanMedian,
            trunkLeanShare: trunkLeanShare
        )
    }
}

/// Posture assessments persisted on device with SwiftData.
final class SwiftDataPostureAssessmentStore: PostureAssessmentStoring {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func fetchAll() throws -> [PostureAssessment] {
        let descriptor = FetchDescriptor<PostureAssessmentEntity>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.value)
    }

    func add(_ assessment: PostureAssessment) throws {
        context.insert(PostureAssessmentEntity(assessment))
        try context.save()
    }

    func deleteAll() throws {
        try context.delete(model: PostureAssessmentEntity.self)
        try context.save()
    }
}
