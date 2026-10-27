import SwiftUI

/// Progress for a chosen period: the posture card, four headline metrics, the programme,
/// and the history of sessions and posture checks. All from data saved on this iPhone.
struct ProgressTabView: View {
    @Binding var selectedTab: AppTab
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = ProgressViewModel()
    @State private var isShowingSettings = false
    @State private var path = NavigationPath()

    var body: some View {
        let dashboard = viewModel.dashboard(history: appModel.history, assessments: appModel.assessments)
        let isEmpty = viewModel.hasNoData(
            history: appModel.history,
            assessments: appModel.assessments,
            errors: [appModel.historyError, appModel.assessmentsError]
        )

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    errors

                    if isEmpty {
                        NoProgressCard(
                            startSession: { selectedTab = .home },
                            checkPosture: { selectedTab = .posture }
                        )
                    } else {
                        Picker("Period", selection: $viewModel.period) {
                            ForEach(ProgressPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("progress.period")

                        PostureScoreCard(
                            state: viewModel.posture(dashboard, assessments: appModel.assessments, error: appModel.assessmentsError),
                            checkPosture: { selectedTab = .posture },
                            retry: appModel.reloadAssessments
                        )
                        metrics(dashboard)
                    }

                    ProgrammeCard(progress: appModel.programme)

                    if !dashboard.allSessions.isEmpty {
                        SessionHistory(sessions: Array(dashboard.allSessions.prefix(20)))
                    }
                    if !appModel.assessments.isEmpty {
                        AssessmentHistory(assessments: appModel.assessments)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
                .animation(Motion.standard(reduceMotion: reduceMotion), value: viewModel.period)
            }
            .background(Color.impostureDashboardBackground.ignoresSafeArea())
            .sensoryFeedback(.selection, trigger: viewModel.period)
            .navigationTitle("Progress")
            .navigationDestination(for: PostureRoute.self) { route in
                switch route {
                case .report(let id): StoredReportView(assessmentID: id) { path.append(PostureRoute.routine($0.id)) }
                case .routine(let id): RoutineDetailView(routineID: id)
                case .score(let day): PostureScoreView(day: day)
                }
            }
            .appRouteDestinations()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
        .task { viewModel.refreshCameraAccess() }
        // Camera access may have changed in Settings while the app was away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshCameraAccess() }
        }
    }

    @ViewBuilder private var errors: some View {
        if let error = appModel.historyError {
            ErrorCard(message: error, retry: appModel.reloadHistory)
        }
    }

    private func metrics(_ dashboard: ProgressDashboard) -> some View {
        let history = appModel.history
        let historyError = appModel.historyError
        return MetricGrid {
            MetricTile(title: "Sessions", systemImage: "checkmark.circle", reading: viewModel.sessions(dashboard, history: history, error: historyError)) {
                SessionDots(dashboard: dashboard)
            }
            MetricTile(title: "Exercise Time", systemImage: "timer", reading: viewModel.exerciseTime(dashboard, history: history, error: historyError)) {
                MiniBars(buckets: dashboard.chart)
            }
        } bottom: {
            let consistency = viewModel.consistency(dashboard, history: history, error: historyError)
            MetricTile(title: "Consistency", systemImage: "repeat", reading: consistency) {
                ConsistencyBar(share: consistency.isKnown ? dashboard.consistency : nil)
            }
            MetricTile(
                title: "Tracking Days",
                systemImage: "calendar",
                reading: viewModel.trackingDays(
                    dashboard,
                    history: history, historyError: historyError,
                    assessments: appModel.assessments, assessmentsError: appModel.assessmentsError
                )
            ) {
                TrackingStrip(days: dashboard.days)
            }
        }
    }
}

// MARK: - Card chrome

private extension View {
    /// The rounded charcoal card every Progress section sits on.
    func dashboardCard(padding: CGFloat = Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.impostureDashboardCard, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }
}

/// Two rows of two; one column at accessibility text sizes so values never truncate.
private struct MetricGrid<Top: View, Bottom: View>: View {
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                top
                bottom
            }
        } else {
            Grid(horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.sm) {
                GridRow { top }
                GridRow { bottom }
            }
        }
    }
}

// MARK: - Posture score

/// The posture score card. The header and ring open the Posture Score screen for the day of the
/// latest check; the action, when there is one, sits below so the two never overlap.
private struct PostureScoreCard: View {
    let state: PostureCardState
    let checkPosture: () -> Void
    let retry: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(value: PostureRoute.score(day)) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    HStack(spacing: Spacing.lg) {
                        // No scoring method exists yet, so the ring stays an empty track.
                        ScoreRing(progress: nil) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("—")
                                    .font(.title.weight(.semibold))
                                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                                Text("/100")
                                    .font(.caption)
                                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                            }
                            .accessibilityHidden(true)
                        }
                        details
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressableCard)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Posture Score")
            .accessibilityIdentifier("progress.posture")

            action
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandGradient.card, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }

    private var day: Date {
        if case .measured(let assessment, _, _) = state { return assessment.endedAt }
        return .now
    }

    private var header: some View {
        HStack {
            Text("Posture Score")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var details: some View {
        switch state {
        case .measured(let assessment, let inRange, let measure):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Not scored yet")
                    .font(.headline)
                    .foregroundStyle(Color.impostureDashboardText)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Circle().fill(Color.impostureAccentFill).frame(width: 8, height: 8)
                    Text(inRange, format: .percent.precision(.fractionLength(0)))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Color.impostureDashboardText)
                    Text("posture range")
                        .font(.subheadline)
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(measure), \(inRange.formatted(.percent.precision(.fractionLength(0))))")
                Text("Latest check, \(assessment.endedAt.formatted(.dateTime.weekday(.abbreviated).day().month()))")
                    .font(.footnote)
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .notEnoughData:
            status("Not enough data", "Take a posture check to see your posture range.")
        case .cameraDenied:
            status("Camera access is off", "Posture checks use the camera to see your side profile. Video never leaves your iPhone.")
        case .unavailable(let message):
            status("Posture results unavailable", message)
        }
    }

    private func status(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.impostureDashboardText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var action: some View {
        switch state {
        case .measured:
            EmptyView()
        case .notEnoughData:
            actionButton("Check posture", action: checkPosture)
        case .cameraDenied:
            actionButton("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .unavailable:
            actionButton("Try again", action: retry)
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.impostureAccentFill)
            .frame(minHeight: TouchTarget.minimum)
    }
}

// MARK: - Metric tiles

private struct MetricTile<Visual: View>: View {
    let title: String
    let systemImage: String
    let reading: MetricReading
    @ViewBuilder var visual: Visual

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .labelStyle(TintedIconLabelStyle())
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reading.value)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(reading.isKnown ? Color.impostureDashboardText : Color.impostureDashboardTextSecondary)
                if let unit = reading.unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.impostureDashboardTextSecondary)
                }
            }
            Text(reading.detail)
                .font(.caption)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if reading.isKnown {
                visual
                    .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard()
        .accessibilityElement(children: .combine)
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(Color.impostureAccentFill)
            configuration.title
        }
    }
}

/// One dot per day, filled on days with a completed routine; for Today, one per session.
private struct SessionDots: View {
    let dashboard: ProgressDashboard

    var body: some View {
        let dots: [Dot] = dashboard.period == .today
            ? (0..<max(dashboard.completedSessions, 1)).map { Dot(id: $0, state: $0 < dashboard.completedSessions ? .done : .open) }
            : dashboard.days.enumerated().map { index, day in
                Dot(id: index, state: day.isFuture ? .future : (day.completedSessions > 0 ? .done : .open))
            }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: min(dots.count, dots.count > 7 ? 10 : 7))
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(dots) { dot in
                Circle()
                    .fill(dot.state == .done ? Color.impostureAccentFill : Color.impostureDashboardElevated)
                    .opacity(dot.state == .future ? 0.4 : 1)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 10)
            }
        }
    }

    private struct Dot: Identifiable {
        enum State { case done, open, future }
        let id: Int
        let state: State
    }
}

/// Minutes per slot. Future slots are left empty; a past slot with no exercise keeps a hairline.
private struct MiniBars: View {
    let buckets: [ProgressDashboard.Bucket]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let peak = max(buckets.map(\.minutes).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: buckets.count > 10 ? 1.5 : 4) {
            ForEach(buckets) { bucket in
                Group {
                    if bucket.isFuture {
                        Color.clear
                    } else {
                        let share = Double(bucket.minutes) / Double(peak)
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2, style: .continuous)
                            .fill(bucket.minutes > 0 ? Color.impostureAccentFill : Color.impostureDashboardElevated)
                            .frame(height: bucket.minutes > 0 ? max(4, 28 * share * (grown ? 1 : 0.05)) : 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .bottom)
            }
        }
        .frame(height: 28)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.7)) { grown = true }
        }
    }
}

private struct ConsistencyBar: View {
    let share: Double?

    var body: some View {
        Capsule()
            .fill(Color.impostureDashboardElevated)
            .overlay(alignment: .leading) {
                if let share {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(BrandGradient.primary)
                            .frame(width: max(proxy.size.width * share, share > 0 ? 6 : 0))
                    }
                }
            }
            .frame(height: 6)
    }
}

/// One segment per day: light green when tracked, empty when not, faint when still to come.
private struct TrackingStrip: View {
    let days: [ProgressDashboard.Bucket]

    var body: some View {
        HStack(spacing: days.count > 10 ? 1.5 : 3) {
            ForEach(days) { day in
                Capsule()
                    .fill(day.isTracked ? Color.impostureGreenLight : Color.impostureDashboardElevated)
                    .opacity(day.isFuture ? 0.4 : 1)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Programme and history

private struct ProgrammeCard: View {
    let progress: ProgrammeProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Label("Ten-day programme", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.impostureDashboardTextSecondary)
                    .labelStyle(TintedIconLabelStyle())
                Spacer()
                Text("\(progress.completedCount) of \(progress.days.count)")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Color.impostureDashboardText)
            }
            HStack(spacing: 4) {
                ForEach(progress.days) { day in
                    Capsule()
                        .fill(progress.status(of: day) == .completed ? Color.impostureAccentFill : Color.impostureDashboardElevated)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .dashboardCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ten-day programme, \(progress.completedCount) of \(progress.days.count) days done")
    }
}

private struct SessionHistory: View {
    let sessions: [CompletedSession]

    var body: some View {
        HistorySection(title: "Recent sessions") {
            ForEach(sessions) { session in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: session.completesRoutine ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(session.completesRoutine ? Color.impostureAccentFill : Color.impostureDashboardTextSecondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.impostureDashboardText)
                        Text("\(session.endedAt.formatted(date: .abbreviated, time: .shortened)) · \(DurationText.short(session.activeSeconds))")
                            .font(.footnote)
                            .foregroundStyle(Color.impostureDashboardTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityValue(session.completesRoutine ? "Completed" : "Ended early")
            }
        }
    }
}

private struct AssessmentHistory: View {
    let assessments: [PostureAssessment]

    var body: some View {
        HistorySection(title: "Posture checks") {
            ForEach(assessments) { assessment in
                NavigationLink(value: PostureRoute.report(assessment.id)) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "figure.seated.side.right")
                            .foregroundStyle(Color.impostureAccentFill)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assessment.endedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.impostureDashboardText)
                            Text(detail(assessment))
                                .font(.footnote)
                                .foregroundStyle(Color.impostureDashboardTextSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.impostureDashboardTextSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, Spacing.xs)
                    .frame(minHeight: TouchTarget.minimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func detail(_ assessment: PostureAssessment) -> String {
        var parts = [DurationText.short(assessment.activeSeconds)]
        if let head = assessment.headForwardMedian { parts.append("head \(Int(head.rounded()))°") }
        if let trunk = assessment.trunkLeanMedian { parts.append("lean \(Int(trunk.rounded()))°") }
        return parts.joined(separator: " · ")
    }
}

private struct HistorySection<Rows: View>: View {
    let title: String
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.sm)
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: rows) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        subviews[index]
                        if index < subviews.count - 1 {
                            Rectangle()
                                .fill(Color.impostureDashboardElevated)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .dashboardCard(padding: Spacing.md)
        }
    }
}

// MARK: - States

private struct NoProgressCard: View {
    let startSession: () -> Void
    let checkPosture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(Color.impostureAccentFill)
                .accessibilityHidden(true)
            Text("Your progress will appear here")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.impostureDashboardText)
            Text("Finish a session or take a posture check, and your sessions, exercise time and posture results will show up here.")
                .font(.subheadline)
                .foregroundStyle(Color.impostureDashboardTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // Side by side when they fit; stacked at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { actions }
                VStack(alignment: .leading, spacing: Spacing.sm) { actions }
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, Spacing.xs)
        }
        .dashboardCard(padding: Spacing.lg)
    }

    @ViewBuilder private var actions: some View {
        Button("Start a session", action: startSession)
            .buttonStyle(.borderedProminent)
            .tint(Color.impostureAccentFill)
            .foregroundStyle(Color.impostureOnAccent)
            .fixedSize()
        Button("Check posture", action: checkPosture)
            .buttonStyle(.bordered)
            .tint(Color.impostureGreenLight)
            .fixedSize()
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.impostureGreenLight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.impostureDashboardText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.impostureAccentFill)
                    .frame(minHeight: TouchTarget.minimum)
            }
        }
        .dashboardCard()
    }
}

#Preview("Sample data") {
    ProgressTabView(selectedTab: .constant(.progress))
        .environment(AppModel.preview())
}
