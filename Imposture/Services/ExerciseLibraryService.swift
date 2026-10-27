import Foundation

protocol ExerciseLibraryProviding {
    func loadLibrary() throws -> ExerciseLibrary
}

enum ExerciseLibraryError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource: "The exercise library is missing from the app."
        }
    }
}

/// Reads the exercise library bundled with the app. Works fully offline.
struct BundledExerciseLibraryService: ExerciseLibraryProviding {
    var bundle: Bundle = .main
    var resourceName = "Library"

    func loadLibrary() throws -> ExerciseLibrary {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ExerciseLibraryError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExerciseLibrary.self, from: data)
    }
}
