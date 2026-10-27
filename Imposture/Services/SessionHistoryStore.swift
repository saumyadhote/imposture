import Foundation
import SwiftData

protocol SessionHistoryStoring {
    func fetchAll() throws -> [CompletedSession]
    func add(_ session: CompletedSession) throws
    func deleteAll() throws
}

@Model
final class CompletedSessionEntity {
    @Attribute(.unique) var id: UUID
    var routineID: String?
    var title: String
    var startedAt: Date
    var endedAt: Date
    var activeSeconds: Double
    var exercisesCompleted: Int
    var exercisesTotal: Int
    var reachedEnd: Bool = false

    init(_ session: CompletedSession) {
        id = session.id
        routineID = session.routineID
        title = session.title
        startedAt = session.startedAt
        endedAt = session.endedAt
        activeSeconds = session.activeSeconds
        exercisesCompleted = session.exercisesCompleted
        exercisesTotal = session.exercisesTotal
        reachedEnd = session.reachedEnd
    }

    var value: CompletedSession {
        CompletedSession(
            id: id,
            routineID: routineID,
            title: title,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            exercisesCompleted: exercisesCompleted,
            exercisesTotal: exercisesTotal,
            reachedEnd: reachedEnd
        )
    }
}

/// Session history persisted on device with SwiftData.
final class SwiftDataSessionHistoryStore: SessionHistoryStoring {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// One container for session history and posture assessments.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: CompletedSessionEntity.self, PostureAssessmentEntity.self,
            configurations: configuration
        )
    }

    func fetchAll() throws -> [CompletedSession] {
        let descriptor = FetchDescriptor<CompletedSessionEntity>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.value)
    }

    func add(_ session: CompletedSession) throws {
        context.insert(CompletedSessionEntity(session))
        try context.save()
    }

    func deleteAll() throws {
        try context.delete(model: CompletedSessionEntity.self)
        try context.save()
    }
}
