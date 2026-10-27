import SwiftUI

/// Home: recommended sessions (led by today's programme day), every guided session,
/// then exercises by posture concern.
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var path = NavigationPath()


    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(greeting)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Color.impostureDashboardText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, Spacing.screenMargin)
                        .padding(.top, Spacing.md)

                    status

                    if let library = appModel.library {
                        RecommendedSessions(
                            cards: SessionRecommendations.make(
                                programme: appModel.programme,
                                routines: library.routines,
                                plan: appModel.plan(for:)
                            ),
                            showDetails: show
                        )
                        GuidedSessionsSection(routines: library.routines, showDetails: show)
                        ConcernsSection()
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.impostureDashboardBackground.ignoresSafeArea())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .appRouteDestinations()
        }
        .onChange(of: appModel.returnHomeCount) { path = NavigationPath() }
    }

    /// The saved-session confirmation and the resume row, when either applies.
    @ViewBuilder private var status: some View {
        if appModel.lastFinishedSession != nil || appModel.resumableSnapshot != nil {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let finished = appModel.lastFinishedSession {
                    SavedBanner(session: finished) { appModel.dismissFinishedConfirmation() }
                        .transition(.opacity)
                }
                if let snapshot = appModel.resumableSnapshot {
                    ResumeRow(snapshot: snapshot)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .animation(.easeOut(duration: 0.2), value: appModel.lastFinishedSession)
        }
    }

    /// "Hello, Saumya", using the name given during onboarding.
    private var greeting: String {
        guard let name = appModel.preferences.name, !name.isEmpty else { return "Hello" }
        return "Hello, \(name)"
    }

    /// Opens a routine's detail screen. A repeat tap while a screen is already pushed does nothing.
    private func show(_ routine: Routine) {
        guard path.isEmpty else { return }
        path.append(AppRoute.routine(routine.id))
    }
}

// MARK: - Shared chrome

private extension View {
    /// The rounded charcoal card Home sections sit on.
    func homeCard(padding: CGFloat = Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }
}

/// A section title with an optional line of supporting text.
private struct HomeSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
    }
}

/// The symbol that stands in for a routine's picture: its main kind of exercise.
private func symbol(for routine: Routine, in library: ExerciseLibrary?) -> String {
    let exercises = library?.exercises(in: routine) ?? []
    return SessionRecommendations.dominantCategory(of: exercises)?.systemImage ?? "figure.mind.and.body"
}

// MARK: - A. Recommended sessions

private struct RecommendedSessions: View {
    let cards: [SessionRecommendation]
    let showDetails: (Routine) -> Void

    var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HomeSectionHeader(title: "Recommended Sessions")
                DepthCarousel(items: cards, identifier: "home.recommended") { card in
                    RecommendationCard(card: card) { showDetails(card.routine) }
                }
            }
        }
    }
}

/// A recommended session. The card opens the routine; the button starts it.
/// Today's programme day is the focal card, lit with the brand green.
private struct RecommendationCard: View {
    let card: SessionRecommendation
    let showDetails: () -> Void
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        Button(action: showDetails) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(card.label.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(card.isProgrammeDay ? Color.impostureAccentFill : Color.impostureDashboardTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(card.routine.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.impostureDashboardText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(card.description)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                Label("\(card.minutes) min", systemImage: "clock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .frame(minHeight: 40, alignment: .center)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(shape)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(card.label). \(card.routine.title). \(card.description) About \(card.minutes) minutes.")
        .accessibilityHint("Shows the exercises in this session")
        .overlay(alignment: .bottomTrailing) {
            Button {
                appModel.startRoutine(card.routine)
            } label: {
                Text("Start Session")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.impostureOnAccent)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 40)
                    .background(BrandGradient.primary, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressableCard)
            .padding(Spacing.lg)
            .accessibilityLabel("Start \(card.routine.title)")
            .accessibilityIdentifier(card.isProgrammeDay ? "home.start" : "home.start.\(card.id)")
        }
        .background { surface }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        // One layer before the 3D turn, so the card rotates as a single surface without seams.
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
    }

    /// The focal card gets depth and a soft pool of green; the rest stay flat charcoal.
    @ViewBuilder private var surface: some View {
        if card.isProgrammeDay && !reduceTransparency {
            ZStack {
                BrandGradient.card
                EllipticalGradient(
                    colors: [Color.impostureAccentFill.opacity(0.28), Color.impostureGreenDeep.opacity(0.1), .clear],
                    center: UnitPoint(x: 0.9, y: 0),
                    startRadiusFraction: 0, endRadiusFraction: 0.75
                )
            }
        } else {
            Color.impostureDashboardCard
        }
    }
}

// MARK: - B. Guided sessions

private struct GuidedSessionsSection: View {
    let routines: [Routine]
    let showDetails: (Routine) -> Void
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let sessions = routines.filter { appModel.plan(for: $0)?.exercises.isEmpty == false }
        VStack(alignment: .leading, spacing: Spacing.md) {
            HomeSectionHeader(title: "Guided Sessions", subtitle: "Short routines for any moment of the day.")
            if sessions.isEmpty {
                Text("No guided sessions are available right now.")
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .homeCard()
                    .padding(.horizontal, Spacing.screenMargin)
            } else {
                TwoColumnGrid(items: sessions) { routine in
                    GuidedSessionCard(routine: routine, minutes: appModel.plan(for: routine)?.roundedMinutes ?? 0) {
                        showDetails(routine)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
            }
        }
    }
}

/// Compact session card: a symbol and the menu, the title and purpose, then a play control
/// with the duration.
private struct GuidedSessionCard: View {
    let routine: Routine
    let minutes: Int
    let showDetails: () -> Void
    @Environment(AppModel.self) private var appModel
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: symbol(for: routine, in: appModel.library))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.impostureGreenLight)
                    .frame(width: tile, height: tile)
                    .background(Color.impostureDashboardElevated, in: .rect(cornerRadius: Radius.control, style: .continuous))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Menu {
                    Button("View Exercises", systemImage: "list.bullet", action: showDetails)
                    Button("Start Session", systemImage: "play") { appModel.startRoutine(routine) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .frame(width: TouchTarget.minimum, height: tile, alignment: .topTrailing)
                        .contentShape(.rect)
                }
                .accessibilityLabel("More for \(routine.title)")
            }

            Button(action: showDetails) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .font(.headline)
                        .foregroundStyle(Color.impostureDashboardText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(routine.summary)
                        .font(.footnote)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.pressableCard)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows the exercises in this session")
            .accessibilityIdentifier("home.session.\(routine.id)")

            Spacer(minLength: 0)

            Button {
                appModel.startRoutine(routine)
            } label: {
                Label("\(minutes)m", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.impostureDashboardText)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 32)
                    .background(Color.impostureDashboardElevated, in: .capsule)
                    // A 44pt hit area without making the pill itself bigger.
                    .padding(.vertical, 6)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressableCard)
            .padding(.vertical, -6)
            .accessibilityLabel("Start \(routine.title), about \(minutes) minutes")
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(Spacing.sm)
        .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }
}

/// Two equal columns whose cards share a row height; one column at accessibility text sizes.
private struct TwoColumnGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @ViewBuilder var card: (Item) -> Card
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                ForEach(items) { card($0) }
            }
        } else {
            Grid(horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.sm) {
                ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
                    GridRow(alignment: .top) {
                        card(items[index])
                        if index + 1 < items.count {
                            card(items[index + 1])
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}

// MARK: - C. Explore by concern

private struct ConcernsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HomeSectionHeader(title: "Explore by Concern", subtitle: "Find exercises for what feels uncomfortable.")
            TwoColumnGrid(items: BodyArea.concerns) { area in
                ConcernCard(area: area)
            }
            .padding(.horizontal, Spacing.screenMargin)
        }
    }
}

private struct ConcernCard: View {
    let area: BodyArea
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationLink(value: AppRoute.area(area)) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: area.systemImage)
                        .font(.title3)
                        .foregroundStyle(Color.impostureGreenLight)
                        .frame(width: 44, height: 44)
                        .background(Color.impostureDashboardElevated, in: .rect(cornerRadius: Radius.control, style: .continuous))
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .accessibilityHidden(true)
                }
                Text(area.concernTitle ?? area.title)
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = area.concernSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(countText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .homeCard()
            .contentShape(.rect)
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows exercises for this concern")
        .accessibilityIdentifier("home.concern.\(area.rawValue)")
    }

    private var countText: String {
        let count = appModel.library?.exercises.count { $0.bodyAreas.contains(area) } ?? 0
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }
}

// MARK: - Resume

private struct ResumeRow: View {
    let snapshot: SessionSnapshot
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RoutineCard(
            eyebrow: "Pick up where you left off",
            title: snapshot.plan.title,
            detail: "\(snapshot.completedCount) of \(snapshot.plan.exercises.count) done"
        ) {
            appModel.resumeInterruptedSession()
        }
        .contextMenu {
            Button("Discard", systemImage: "trash", role: .destructive) {
                appModel.discardResumableSession()
            }
        }
        .accessibilityHint("Resumes your unfinished session")
        .accessibilityIdentifier("today.resume")
    }
}

#Preview {
    HomeView()
        .environment(AppModel.preview())
}
