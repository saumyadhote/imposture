import SwiftUI

/// The full exercise catalogue, pushed from Home: short routines, then every exercise by
/// category. Search sits in the navigation bar; position and body-area filters in the toolbar.
struct ExerciseCatalogueView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        Group {
            if let library = appModel.library {
                catalogue(library)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .impostureScreenBackground()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search exercises or body areas"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FilterMenu(position: $viewModel.position, area: $viewModel.area)
            }
        }
    }

    @ViewBuilder
    private func catalogue(_ library: ExerciseLibrary) -> some View {
        let results = viewModel.results(in: library)
        if viewModel.isFiltering && results.isEmpty {
            ContentUnavailableView {
                Label("No matching exercises", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different word, like “neck” or “standing”.")
            } actions: {
                Button("Clear search and filters") { viewModel.clearFilters() }
                    .buttonStyle(.bordered)
            }
        } else {
            List {
                if viewModel.isFiltering {
                    Section(resultsTitle(results.count)) {
                        rows(results)
                    }
                } else {
                    Section("Short routines") {
                        ForEach(library.routines) { routine in
                            NavigationLink(value: AppRoute.routine(routine.id)) {
                                GuidedSessionRow(routine: routine, plan: SessionPlan(routine: routine, library: library))
                            }
                            .listRowBackground(Color.impostureSurface)
                        }
                    }
                    ForEach(library.categories) { category in
                        Section(category.title) {
                            rows(library.exercises(in: category))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .headerProminence(.increased)
            .scrollContentBackground(.hidden)
        }
    }

    private func rows(_ exercises: [Exercise]) -> some View {
        ForEach(exercises) { exercise in
            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                CatalogueExerciseRow(exercise: exercise)
            }
            .listRowBackground(Color.impostureSurface)
        }
    }

    private func resultsTitle(_ count: Int) -> String {
        let base = count == 1 ? "1 exercise" : "\(count) exercises"
        let filters = [viewModel.position?.title, viewModel.area?.title].compactMap { $0 }
        return filters.isEmpty ? base : "\(base) · \(filters.joined(separator: ", "))"
    }
}

/// Position and body-area filters, as a native menu with checkmarks.
private struct FilterMenu: View {
    @Binding var position: ExercisePosition?
    @Binding var area: BodyArea?

    var body: some View {
        Menu {
            Picker("Position", selection: $position) {
                Text("Any position").tag(ExercisePosition?.none)
                ForEach(ExercisePosition.allCases) { position in
                    Label(position.title, systemImage: position.systemImage)
                        .tag(Optional(position))
                }
            }
            .pickerStyle(.inline)

            Picker("Body area", selection: $area) {
                Text("All body areas").tag(BodyArea?.none)
                ForEach(BodyArea.allCases) { area in
                    Label(area.title, systemImage: area.systemImage)
                        .tag(Optional(area))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: isActive
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("library.filter")
    }

    private var isActive: Bool { position != nil || area != nil }

    private var accessibilityValue: String {
        let parts = [position?.title, area?.title].compactMap { $0 }
        return parts.isEmpty ? "No filters" : parts.joined(separator: ", ")
    }
}

private struct GuidedSessionRow: View {
    let routine: Routine
    let plan: SessionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(routine.title)
                .font(.headline)
                .foregroundStyle(Color.impostureTextPrimary)
            Text(routine.summary)
                .font(.subheadline)
                .foregroundStyle(Color.impostureTextSecondary)
                .lineLimit(2)
            HStack(spacing: Spacing.md) {
                Label("\(plan.roundedMinutes) min", systemImage: "clock")
                Label(plan.exercises.count == 1 ? "1 exercise" : "\(plan.exercises.count) exercises", systemImage: "list.bullet")
            }
            .font(.footnote)
            .foregroundStyle(Color.impostureTextSecondary)
            .padding(.top, 2)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

/// Catalogue row: the exercise's figure, then name, summary and facts.
struct CatalogueExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Spacing.md) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.impostureTextPrimary)
                Text(exercise.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureTextSecondary)
                    .lineLimit(2)
                HStack(spacing: Spacing.md) {
                    Label(DurationText.short(exercise.duration), systemImage: "clock")
                    Label(exercise.position.title, systemImage: exercise.position.systemImage)
                }
                .font(.footnote)
                .foregroundStyle(Color.impostureTextSecondary)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// Exercises for one body area. Opened from a concern on Home, it leads with the concern.
struct AreaExercisesView: View {
    let area: BodyArea
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let exercises = appModel.library?.exercises.filter { $0.bodyAreas.contains(area) } ?? []
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: area.systemImage,
                    description: Text("There are no exercises for this area yet.")
                )
            } else {
                List {
                    if let summary = area.concernSummary {
                        Section {
                            HStack(alignment: .center, spacing: Spacing.md) {
                                Image(systemName: area.systemImage)
                                    .font(.title2)
                                    .foregroundStyle(Color.impostureGreenLight)
                                    .frame(width: 52, height: 52)
                                    .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.control, style: .continuous))
                                    .accessibilityHidden(true)
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    Section(exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises") {
                        ForEach(exercises) { exercise in
                            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                                CatalogueExerciseRow(exercise: exercise)
                            }
                            .listRowBackground(Color.impostureDashboardCard)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.impostureDashboardBackground.ignoresSafeArea())
        .navigationTitle(area.concernTitle ?? area.title)
    }
}

/// Exercises in one catalogue category.
struct CategoryExercisesView: View {
    let category: ExerciseCategory
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let exercises = appModel.library?.exercises(in: category) ?? []
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: category.systemImage,
                    description: Text("There are no exercises in this category yet.")
                )
            } else {
                List {
                    Section(exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises") {
                        ForEach(exercises) { exercise in
                            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                                CatalogueExerciseRow(exercise: exercise)
                            }
                            .listRowBackground(Color.impostureSurface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .impostureScreenBackground()
        .navigationTitle(category.title)
    }
}

#Preview {
    NavigationStack {
        ExerciseCatalogueView()
            .appRouteDestinations()
    }
    .environment(AppModel.preview())
}
