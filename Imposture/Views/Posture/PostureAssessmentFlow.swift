import SwiftUI
import UIKit

/// The full-screen assessment: positioning guidance, the timed assessment, a short
/// transition while the result is worked out, then the report.
struct PostureAssessmentFlow: View {
    /// Called with a programme day chosen from the report.
    let onOpenRecommended: (Routine) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: PostureAssessmentViewModel?
    @State private var isConfirmingCancel = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .impostureScreenBackground()
        .onAppear {
            if viewModel == nil {
                viewModel = PostureAssessmentViewModel(camera: CameraService()) { appModel.record($0) }
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: PostureAssessmentViewModel) -> some View {
        NavigationStack {
            phaseView(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(Motion.standard(reduceMotion: reduceMotion), value: viewModel.phase)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(viewModel.phase == .assessing ? "Cancel" : "Close", systemImage: "xmark") {
                            if viewModel.phase == .assessing {
                                viewModel.pause()
                                isConfirmingCancel = true
                            } else {
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("assessment.close")
                    }
                    if viewModel.phase == .positioning {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task { await viewModel.switchCamera() }
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                            }
                            .accessibilityLabel(viewModel.isUsingFrontCamera ? "Switch to back camera" : "Switch to front camera")
                        }
                    }
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.prepare()
            await viewModel.run()
        }
        .onDisappear {
            viewModel.suspend()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.resumeCamera() }
            } else {
                viewModel.suspend()
            }
        }
        .onChange(of: viewModel.phase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .assessing || phase == .positioning
        }
        .alert("Cancel this assessment?", isPresented: $isConfirmingCancel) {
            Button("Keep going", role: .cancel) { viewModel.resume() }
            Button("Cancel assessment", role: .destructive) { viewModel.cancel() }
        } message: {
            Text("Nothing from this assessment will be kept.")
        }
        .sensoryFeedback(.success, trigger: viewModel.phase) { _, phase in
            if case .report = phase { true } else { false }
        }
    }

    @ViewBuilder
    private func phaseView(_ viewModel: PostureAssessmentViewModel) -> some View {
        switch viewModel.phase {
        case .idle, .requestingAccess:
            ProgressView("Starting camera")
        case .denied:
            StateMessage(
                title: "Camera access is off",
                message: "Allow camera access in Settings to assess your posture. Frames are analysed on this iPhone and never saved.",
                systemImage: "camera.badge.ellipsis"
            ) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.imposturePrimary)
            }
        case .unavailable:
            StateMessage(
                title: "No camera available",
                message: "The posture assessment needs a camera. Try it on your iPhone.",
                systemImage: "camera"
            )
        case .failed(let message):
            StateMessage(title: "Something went wrong", message: message, systemImage: "exclamationmark.triangle") {
                Button("Try again") { Task { await viewModel.retryAfterFailure() } }
                    .buttonStyle(.impostureSecondary)
            }
        case .positioning:
            PositioningView(viewModel: viewModel)
        case .assessing:
            AssessingView(viewModel: viewModel)
        case .processing:
            AnalysisTransition()
                .transition(.opacity)
        case .report(let assessment):
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    PostureReportView(
                        analysis: ProgressViewModel().analysis(for: assessment, in: appModel.assessments),
                        recommended: appModel.recommendedDay(for: assessment),
                        onOpenRecommended: onOpenRecommended
                    )
                    if viewModel.saveFailed {
                        NoteBox(title: "Not saved", message: "This result couldn't be saved, so it won't appear in Progress.", systemImage: "exclamationmark.triangle")
                    }
                    Button("Done") { dismiss() }
                        .buttonStyle(.imposturePrimary)
                        .accessibilityIdentifier("assessment.done")
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.lg)
            }
            .transition(.opacity)
        case .insufficient:
            StateMessage(
                title: "Not enough to go on",
                message: "Your head, shoulder and hip weren't clearly in view for long enough. Check the camera can see your side, then try again.",
                systemImage: "person.fill.questionmark"
            ) {
                Button("Try again") { Task { await viewModel.startOver() } }
                    .buttonStyle(.imposturePrimary)
            }
        }
    }
}

// MARK: - Positioning

private struct PositioningView: View {
    @Bindable var viewModel: PostureAssessmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            CameraFrame(viewModel: viewModel)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Guidance(number: 1, text: "Prop your iPhone upright about two metres to your side, near chest height.")
                Guidance(number: 2, text: "Check your head, shoulders and hips are all in the frame.")
                Guidance(number: 3, text: "Sit and work as you normally would until the timer ends.")
            }

            Picker("Length", selection: $viewModel.length) {
                ForEach(AssessmentLength.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Assessment length")

            Button("Start assessment") { viewModel.start() }
                .buttonStyle(.imposturePrimary)
                .accessibilityIdentifier("assessment.start")
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.md)
    }
}

private struct Guidance: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.impostureOnAccent)
                .frame(width: 22, height: 22)
                .background(Color.impostureSecondaryAccent, in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.impostureTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Live preview with framing feedback from the pose estimate.
private struct CameraFrame: View {
    let viewModel: PostureAssessmentViewModel
    var dimmed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.impostureSurface
            if let session = viewModel.camera.previewSession {
                CameraPreview(session: session)
                    .opacity(dimmed ? 0.45 : 1)
                    .accessibilityLabel("Camera preview")
            }
            FramingBadge(framing: viewModel.framing)
                .padding(Spacing.sm)
        }
        .clipShape(.rect(cornerRadius: Radius.plate, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.plate, style: .continuous)
                .strokeBorder(viewModel.framing == .good ? Color.impostureSecondaryAccent : Color.impostureSeparator, lineWidth: 2)
        )
    }
}

private struct FramingBadge: View {
    let framing: PostureMetrics.Framing

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.impostureTextPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var text: String {
        switch framing {
        case .noPerson: "Looking for you"
        case .partial: "Move so your head and hips are in view"
        case .good: "You're in frame"
        }
    }

    private var symbol: String {
        switch framing {
        case .noPerson: "person.crop.rectangle"
        case .partial: "arrow.up.and.down.and.arrow.left.and.right"
        case .good: "checkmark.circle.fill"
        }
    }
}

// MARK: - Assessing

private struct AssessingView: View {
    let viewModel: PostureAssessmentViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            CameraFrame(viewModel: viewModel, dimmed: true)
                .overlay {
                    VStack(spacing: Spacing.xxs) {
                        Text(DurationText.clock(max(0, viewModel.remainingSeconds)))
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .foregroundStyle(Color.impostureTextPrimary)
                        Text(viewModel.isPaused ? "Paused" : "Sit as you normally would")
                            .font(.subheadline)
                            .foregroundStyle(viewModel.isPaused ? Color.impostureSecondaryAccent : Color.impostureTextSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(viewModel.isPaused ? "Paused" : "Assessing")
                    .accessibilityValue(DurationText.spokenRemaining(max(0, viewModel.remainingSeconds)))
                }

            ProgressView(value: viewModel.progress)
                .tint(Color.impostureAccentFill)
                .accessibilityHidden(true)

            HStack(spacing: Spacing.sm) {
                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    viewModel.isPaused ? viewModel.resume() : viewModel.pause()
                }
                .buttonStyle(.impostureSecondary)
                .accessibilityIdentifier("assessment.pause")

                Button("Finish") { Task { await viewModel.finish() } }
                    .buttonStyle(.imposturePrimary)
                    .disabled(!viewModel.canFinish)
                    .accessibilityHint(viewModel.canFinish ? "Ends now and shows your report" : "Available after 30 seconds")
                    .accessibilityIdentifier("assessment.finish")
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.md)
    }
}

// MARK: - Transition

/// Shown only while the result is actually being worked out.
private struct AnalysisTransition: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            BrandMark()
            ProgressView()
                .tint(Color.impostureAccentFill)
            Text("Understanding your posture")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.impostureTextPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
