import SwiftUI

/// The ten-day programme, one row per day. Every day can be opened and repeated; completed
/// days are marked, and days still to come are shown as upcoming rather than locked.
struct ProgrammeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let progress = appModel.programme
        List {
            Section {
                ForEach(progress.days) { day in
                    NavigationLink(value: AppRoute.routine(day.id)) {
                        DayRow(day: day, minutes: appModel.plan(for: day)?.roundedMinutes, status: progress.status(of: day))
                    }
                    .listRowBackground(Color.impostureDashboardCard)
                }
            } header: {
                Text("\(progress.completedCount) of \(progress.days.count) days done")
            } footer: {
                Text("Days build on each other, but none are locked. A day is marked done when you finish its routine.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.impostureDashboardBackground.ignoresSafeArea())
        .navigationTitle("Your 10-Day Reset")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DayRow: View {
    let day: Routine
    let minutes: Int?
    let status: ProgrammeProgress.Status

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(status == .upcoming ? Color.impostureDashboardTextSecondary : Color.impostureAccentFill)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(day.day ?? 0)\(status == .current ? " · Up next" : "")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status == .current ? Color.impostureAccentFill : Color.impostureDashboardTextSecondary)
                Text(day.title)
                    .font(.headline)
                    .foregroundStyle(status == .upcoming ? Color.impostureDashboardTextSecondary : Color.impostureDashboardText)
                if let minutes {
                    Text("About \(minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status == .completed ? "Completed" : status == .current ? "Up next" : "Upcoming")
    }

    private var icon: String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .current: "arrow.forward.circle.fill"
        case .upcoming: "circle.dotted"
        }
    }
}

#Preview {
    NavigationStack {
        ProgrammeView()
            .appRouteDestinations()
    }
    .environment(AppModel.preview())
}
