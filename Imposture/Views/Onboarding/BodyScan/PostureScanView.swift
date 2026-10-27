//
//  PostureScanView.swift
//  Team-5
//
//  Automated Multi-Angle Camera Posture Scanner with Strict Physical Barriers & Siri Voice Director
//  Captures 5 high-speed biometric frames per face/angle (Front -> Right -> Left -> Back)
//  Computes Craniovertebral Angle (CVA), Acromion Disparity, and Hansraj Neck Load
//  Voice guidance ensures effortless capture, especially for back view where screen is occluded
//

import SwiftUI
import AVFoundation

struct PostureScanView: View {
    var onScanCompleted: (MultiAngleScanData) -> Void
    /// Leaves the scan without results, for when the camera can't be used.
    var onSkip: () -> Void = {}
    var onBack: (() -> Void)? = nil
    
    @StateObject private var cameraDetector = CameraPoseDetector()
    @StateObject private var voiceDirector = PostureScanVoiceDirector.shared
    @State private var currentAngle: ScanAngle = .front
    @State private var showCaptureFlash = false
    @State private var scanPulse = false
    @State private var transitionMessage: String? = nil
    @State private var isAnalyzing = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Navigation Bar
                HStack(spacing: 8) {
                    if let onBack = onBack {
                        CircleIconButton(systemImage: "chevron.left", label: "Go back") {
                            voiceDirector.stop()
                            onBack()
                        }
                    }
                    
                    Spacer()
                    
                    // Voice Guidance Toggle (Siri Voice)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        _ = voiceDirector.toggleMute()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: voiceDirector.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(voiceDirector.isMuted ? AppTheme.textSecondary : AppTheme.limeAccent)
                            Text(voiceDirector.isMuted ? "Muted" : "Voice on")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(voiceDirector.isMuted ? AppTheme.textSecondary : AppTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(AppTheme.surfaceEmphasis)
                        )
                    }
                    .accessibilityLabel(voiceDirector.isMuted ? "Unmute voice guidance" : "Mute voice guidance")
                    
                    // Burst frames counter indicator
                    HStack(spacing: 4) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.limeAccent)
                        Text("5 frames/angle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(AppTheme.surfaceEmphasis)
                    )
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentAngle.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(currentAngle.subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                
                // MARK: - Step Indicators (Front -> Right -> Left -> Back)
                HStack(spacing: 8) {
                    stepIndicator(for: .front, label: "Front")
                    stepIndicator(for: .right, label: "Right")
                    stepIndicator(for: .left, label: "Left")
                    stepIndicator(for: .back, label: "Back")
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // Back View Special Voice Assistance Banner
                if currentAngle == .back {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.limeAccent)
                        Text("Voice guidance on · it will guide you and count down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.surfaceEmphasis)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.limeAccent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Camera Viewport & Live Reticle
                ZStack {
                    // Viewport Background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 18/255, green: 18/255, blue: 22/255))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(AppTheme.separator, lineWidth: 1)
                        )
                    
                    // Hardware Camera Preview
                    if cameraDetector.hasHardwareCamera && cameraDetector.isRunning {
                        CameraPreviewView(session: cameraDetector.captureSession)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        // Simulated scanning sweep
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, AppTheme.limeAccent.opacity(0.15), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 120)
                                .offset(y: scanPulse ? 140 : -140)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: scanPulse)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    
                    // Body Silhouette Guide
                    BodySilhouetteOverlay()
                        .stroke(
                            reticleStrokeColor,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                        )
                        .frame(width: 180, height: 320)
                    
                    // Corner Brackets
                    CornerReticlesOverlay()
                        .stroke(reticleStrokeColor, lineWidth: 3.5)
                        .padding(28)
                        .animation(.easeInOut(duration: 0.2), value: cameraDetector.holdProgress)
                    
                    // Top Barrier Guidance Pill
                    VStack {
                        guidancePill
                            .padding(.top, 16)
                        Spacer()
                    }
                    
                    // White Flash on Capture
                    if showCaptureFlash {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.75))
                            .transition(.opacity)
                    }
                    
                    // Angle Transition Overlay
                    if let msg = transitionMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.limeAccent)
                            
                            Text(msg)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppTheme.surfaceEmphasis.opacity(0.95))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppTheme.limeAccent.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 32)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                
                // MARK: - Bottom Micro-copy
                Text(currentAngle == .back ? "Turn your back. The voice guide will tell you when capture is complete." : "Align your body in the guide. Captures automatically when steady.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                
                // MARK: - Actions (Retake & Simulator controls)
                HStack(spacing: 12) {
                    Button(action: retakeCurrentAngle) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake \(currentAngle.rawValue)")
                        }
                        .font(AppTheme.buttonFont())
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(AppTheme.surfaceEmphasis)
                                .overlay(
                                    Capsule().stroke(AppTheme.separator, lineWidth: 1)
                                )
                        )
                    }
                    .accessibilityLabel("Retake current angle")
                    
                    if cameraDetector.isCameraUnavailable || !cameraDetector.hasCameraPermission {
                        Button("Continue without scan", action: onSkip)
                            .font(AppTheme.buttonFont())
                            .foregroundColor(AppTheme.limeAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .accessibilityIdentifier("scan.skip")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            
            // MARK: - Analyzing Biomechanics Full-Screen Transition
            if isAnalyzing {
                ZStack {
                    AppTheme.background.opacity(0.96).ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.limeAccent))
                            .scaleEffect(1.6)
                        
                        Text("Analysing your scan…")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Working out your neck angle, shoulder level and balance from the views you captured.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraDetector.setTargetAngle(currentAngle)
            cameraDetector.checkPermissionAndStart()
            scanPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                voiceDirector.announceAngleIntro(for: currentAngle)
            }
        }
        .onDisappear {
            cameraDetector.stopSession()
            voiceDirector.stop()
        }
        .onChange(of: cameraDetector.barrierState) { _, newState in
            switch newState {
            case .holding(let progress, _):
                voiceDirector.announceHolding(for: currentAngle, progress: progress)
            case .violated(let msg, let isWarning):
                if isWarning {
                    voiceDirector.announceGuidanceWarning(msg)
                }
            default:
                break
            }
        }
        .onChange(of: cameraDetector.isAutoCaptureTriggered) { _, triggered in
            if triggered {
                handleAutoCaptureTriggered()
            }
        }
    }
    
    // MARK: - Dynamic Reticle Color
    private var reticleStrokeColor: Color {
        switch cameraDetector.barrierState {
        case .holding, .burstCapturing, .captured:
            return AppTheme.limeAccent
        case .violated(_, let isWarning):
            return isWarning ? Color.impostureGreenLight : AppTheme.limeAccent.opacity(0.5)
        case .searching:
            return AppTheme.limeAccent.opacity(0.4)
        }
    }
    
    // MARK: - Guidance Pill with Hold & Burst Progress
    @ViewBuilder
    private var guidancePill: some View {
        HStack(spacing: 8) {
            switch cameraDetector.barrierState {
            case .burstCapturing(_, let currentFrame, let totalFrames, let msg):
                HStack(spacing: 4) {
                    ForEach(1...totalFrames, id: \.self) { idx in
                        Circle()
                            .fill(idx <= currentFrame ? AppTheme.limeAccent : AppTheme.separator)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(msg)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.limeAccent)
                
            case .holding(let progress, let msg):
                ZStack {
                    Circle()
                        .stroke(AppTheme.separator, lineWidth: 2.5)
                        .frame(width: 16, height: 16)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppTheme.limeAccent, lineWidth: 2.5)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                }
                Text(msg)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
            case .violated(let msg, let isWarning):
                Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isWarning ? Color.impostureGreenLight : AppTheme.textSecondary)
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
            case .captured(_, let msg):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.limeAccent)
                Text(msg)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
            case .searching(let msg):
                Circle()
                    .fill(AppTheme.textSecondary)
                    .frame(width: 6, height: 6)
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.surfaceEmphasis.opacity(0.94))
                .overlay(
                    Capsule().stroke(AppTheme.separator, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Step Indicator
    @ViewBuilder
    private func stepIndicator(for angle: ScanAngle, label: String) -> some View {
        let isCurrent = currentAngle == angle
        let isCaptured = isAngleCaptured(angle)
        
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isCaptured || isCurrent ? AppTheme.limeAccent : AppTheme.separator)
                .frame(height: 4)
            
            HStack(spacing: 3) {
                if isCaptured {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.limeAccent)
                }
                Text(label)
                    .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func isAngleCaptured(_ angle: ScanAngle) -> Bool {
        switch angle {
        case .front: return cameraDetector.multiAngleData.front != nil || !cameraDetector.multiAngleData.frontFrames.isEmpty
        case .right: return cameraDetector.multiAngleData.right != nil || !cameraDetector.multiAngleData.rightFrames.isEmpty
        case .left: return cameraDetector.multiAngleData.left != nil || !cameraDetector.multiAngleData.leftFrames.isEmpty
        case .back: return cameraDetector.multiAngleData.back != nil || !cameraDetector.multiAngleData.backFrames.isEmpty
        }
    }
    
    // MARK: - Auto-Capture & Angle Transition Handling
    private func handleAutoCaptureTriggered() {
        // Trigger white flash animation
        withAnimation(.easeIn(duration: 0.12)) {
            showCaptureFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCaptureFlash = false
            }
        }
        
        if let next = currentAngle.nextAngle {
            voiceDirector.announceBurstCaptured(for: currentAngle, nextAngle: next)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                transitionMessage = "\(currentAngle.title) Verified (5 frames)\nTurn to \(next.title)"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation {
                    transitionMessage = nil
                    currentAngle = next
                    cameraDetector.isAutoCaptureTriggered = false
                    cameraDetector.setTargetAngle(next)
                    voiceDirector.announceAngleIntro(for: next)
                }
            }
        } else {
            // All 4 angles captured (20 frames verified!) -> Transition to Analysis
            voiceDirector.announceBurstCaptured(for: currentAngle, nextAngle: nil)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                transitionMessage = "All 4 Angles Verified (20 frames)!"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnalyzing = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    var completedData = cameraDetector.multiAngleData
                    completedData.isScanCompleted = true
                    onScanCompleted(completedData)
                }
            }
        }
    }
    
    private func retakeCurrentAngle() {
        cameraDetector.isAutoCaptureTriggered = false
        cameraDetector.setTargetAngle(currentAngle)
        voiceDirector.announceAngleIntro(for: currentAngle)
    }
    
}

// MARK: - Hardware Camera Preview (UIViewRepresentable)
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
    
    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Vector Silhouette & Reticle Overlays
private nonisolated struct BodySilhouetteOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Head oval
        let headRect = CGRect(x: w * 0.35, y: h * 0.05, width: w * 0.30, height: h * 0.22)
        path.addEllipse(in: headRect)
        
        // Neck
        path.move(to: CGPoint(x: w * 0.44, y: h * 0.27))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.33))
        path.move(to: CGPoint(x: w * 0.56, y: h * 0.27))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.33))
        
        // Shoulders & Torso outline
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.39))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.33))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.33))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.39))
        
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.85))
        path.closeSubpath()
        
        return path
    }
}

private nonisolated struct CornerReticlesOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 26
        
        // Top-Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        
        // Top-Right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        
        // Bottom-Left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        
        // Bottom-Right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        
        return path
    }
}
