import SwiftUI

enum AppTab: Hashable {
    case home
    case posture
    case progress
}

/// Destinations pushed inside any tab's navigation stack.
enum AppRoute: Hashable {
    case routine(String)
    case exercise(String)
    case area(BodyArea)
    case category(ExerciseCategory)
    /// The full, searchable exercise catalogue.
    case catalogue
    /// Every day of the ten-day programme, with its status.
    case programme
}

/// The bottom navigation: Home (sessions and the exercise catalogue), Posture and Progress.
/// A system tab bar, so it gets Liquid Glass, accessibility and size-class behaviour for free.
struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Posture", systemImage: "figure.seated.side.right", value: .posture) {
                PostureAssessmentView()
            }
            // Settings opens from the gear button on Progress.
            Tab("Progress", systemImage: "chart.bar", value: .progress) {
                ProgressTabView(selectedTab: $selection)
            }
        }
        // "Back to Home" after a session means the Home tab, at its top.
        .onChange(of: appModel.returnHomeCount) { selection = .home }
    }
}

extension View {
    /// Registers every pushable screen. Applied once per navigation stack.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .routine(let id): RoutineDetailView(routineID: id)
            case .exercise(let id): ExerciseDetailView(exerciseID: id)
            case .area(let area): AreaExercisesView(area: area)
            case .category(let category): CategoryExercisesView(category: category)
            case .catalogue: ExerciseCatalogueView()
            case .programme: ProgrammeView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppModel.preview())
}
