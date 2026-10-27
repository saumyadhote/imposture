import Foundation
import Observation

/// Search and filter state for the Library tab.
@MainActor @Observable
final class LibraryViewModel {
    var searchText = ""
    var position: ExercisePosition?
    var area: BodyArea?

    var isFiltering: Bool {
        !trimmedQuery.isEmpty || position != nil || area != nil
    }

    /// Exercises matching the current search text and position filter.
    func results(in library: ExerciseLibrary) -> [Exercise] {
        library.exercises.filter { exercise in
            matchesPosition(exercise) && matchesArea(exercise) && matchesQuery(exercise)
        }
    }

    func exercises(in library: ExerciseLibrary, for area: BodyArea) -> [Exercise] {
        library.exercises.filter { $0.bodyAreas.contains(area) }
    }

    func clearFilters() {
        searchText = ""
        position = nil
        area = nil
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesArea(_ exercise: Exercise) -> Bool {
        area.map { exercise.bodyAreas.contains($0) } ?? true
    }

    private func matchesPosition(_ exercise: Exercise) -> Bool {
        position.map { $0 == exercise.position } ?? true
    }

    /// Every word typed must appear in the name, summary, body areas or position.
    private func matchesQuery(_ exercise: Exercise) -> Bool {
        let words = trimmedQuery.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = ([exercise.name, exercise.summary, exercise.position.title]
            + exercise.bodyAreas.map(\.title))
            .joined(separator: " ")
        return words.allSatisfy { haystack.localizedStandardContains($0) }
    }
}
