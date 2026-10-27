import SwiftUI

/// Session overview: the day, what's in it and how long it takes, with one action to start.
struct RoutineDetailView: View {
    let routineID: String
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let routine = appModel.library?.routine(id: routineID), let plan = appModel.plan(for: routine) {
            content(routine: routine, plan: plan)
        } else {
            ContentUnavailableView(
                "Session not found",
                systemImage: "questionmark.circle",
                description: Text("This session isn't available any more.")
            )
            .impostureScreenBackground()
        }
    }

    private func content(routine: Routine, plan: SessionPlan) -> some View {
        let status = routine.isProgrammeDay ? appModel.programme.status(of: routine) : nil
        return List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let day = routine.day {
                        HStack(spacing: Spacing.xs) {
                            Text("Day \(day) of 10")
                            if status == .completed {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Color.impostureAccentFill)
                            } else if status == .current {
                                Text("· Up next")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                    }
                    Text(routine.title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.impostureDashboardText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(routine.summary)
                        .font(.body)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Spacing.md) { facts(plan) }
                        VStack(alignment: .leading, spacing: Spacing.xxs) { facts(plan) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .padding(.top, Spacing.xxs)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.xxs, bottom: Spacing.xs, trailing: Spacing.xxs))
            }

            if routine.isProgrammeDay {
                Section {
                    NavigationLink(value: AppRoute.programme) {
                        Label("All ten days", systemImage: "calendar")
                            .foregroundStyle(Color.impostureDashboardText)
                    }
                    .listRowBackground(Color.impostureDashboardCard)
                }
            }

            if let intro = routine.intro {
                Section {
                    Label(intro, systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.impostureDashboardText)
                        .listRowBackground(Color.impostureDashboardCard)
                }
            }

            Section {
                ForEach(Array(plan.exercises.enumerated()), id: \.offset) { offset, exercise in
                    NavigationLink(value: AppRoute.exercise(exercise.id)) {
                        StepRow(number: offset + 1, exercise: exercise)
                    }
                    .listRowBackground(Color.impostureDashboardCard)
                }
            } header: {
                Text("\(plan.exercises.count) exercises")
            } footer: {
                Text("Every exercise is timed. Durations are starting points and are still being reviewed. Opening a session never marks it done; finishing it does.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.impostureDashboardBackground.ignoresSafeArea())
        .navigationTitle(routine.day.map { "Day \($0)" } ?? routine.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                appModel.startRoutine(routine)
            } label: {
                Label(status == .completed ? "Start Again" : "Start Routine", systemImage: "play.fill")
            }
            .buttonStyle(.imposturePrimary)
            .accessibilityLabel("Start \(routine.title)")
            .accessibilityIdentifier("routine.start")
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
            .background(Color.impostureDashboardBackground.ignoresSafeArea(edges: .horizontal))
        }
    }

    @ViewBuilder
    private func facts(_ plan: SessionPlan) -> some View {
        Label("About \(plan.roundedMinutes) min", systemImage: "clock")
        if let equipment = equipmentText(plan) {
            Label(equipment, systemImage: "checklist")
        }
    }

    /// Everything the routine needs, in the order it's first used.
    private func equipmentText(_ plan: SessionPlan) -> String? {
        var seen: [String] = []
        for title in plan.exercises.compactMap(\.equipment.title) where !seen.contains(title) {
            seen.append(title)
        }
        return seen.isEmpty ? nil : seen.joined(separator: ", ")
    }
}

private struct StepRow: View {
    let number: Int
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ExerciseThumbnail(exercise: exercise, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                Text("\(DurationText.short(exercise.duration)) · \(exercise.repsGuide)")
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                if !exercise.instruction.isEmpty {
                    Text(exercise.instruction)
                        .font(.footnote)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exercise \(number): \(exercise.name), \(DurationText.short(exercise.duration))")
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routineID: "day-1")
    }
    .environment(AppModel.preview())
}
