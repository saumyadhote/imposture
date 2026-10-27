//
//  PostureScanIntroView.swift
//  Team-5
//
//  Figma Node: 2131:3033 & 2131:3050 ("Let's scan your posture")
//  Features setup instructions half-sheet modal and clean transitions.
//

import SwiftUI

struct PostureScanIntroView: View {
    var onStartScan: () -> Void
    var onSkip: () -> Void
    var onBack: () -> Void
    
    @State private var showInstructionsSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Bar
            HStack {
                CircleIconButton(systemImage: "chevron.left", label: "Back to focus selection", action: onBack)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // MARK: - Heading
            VStack(alignment: .leading, spacing: 8) {
                Text("Let’s scan your\nposture")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineSpacing(4)
                
                Text("Get a quick look at your posture and see where you could use a little support.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer(minLength: 16)
            
            // MARK: - Illustration
            OnboardingArt(name: "scan_intro_desk", label: "Scan setup illustration placeholder", height: 240)
                .padding(.horizontal, 20)
            
            Spacer(minLength: 24)
            
            // MARK: - Bottom Actions
            VStack(spacing: 12) {
                AppButton("Start scan", icon: "viewfinder") {
                    showInstructionsSheet = true
                }
                .accessibilityLabel("Start posture scan")
                .accessibilityIdentifier("onboarding.startScan")
                
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(AppTheme.buttonFont())
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .accessibilityLabel("Skip posture scan for now")
                .accessibilityIdentifier("onboarding.skipScan")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showInstructionsSheet) {
            setupInstructionsSheet
                .presentationDetents([.fraction(0.58), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.surface)
        }
    }
    
    // MARK: - Setup Tips Half-Sheet
    private var setupInstructionsSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Camera")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, 12)
            
            Text("INSTRUCTIONS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .tracking(1.2)
            
            VStack(spacing: 18) {
                tipRow(
                    icon: "iphone.gen3",
                    title: "Prop your phone at chest height",
                    subtitle: "Lean it against something steady"
                )
                tipRow(
                    icon: "ruler",
                    title: "Stand about 2 m away",
                    subtitle: "Your whole body should fit in the frame"
                )
                tipRow(
                    icon: "sun.max.fill",
                    title: "Use even lighting",
                    subtitle: "Face a window or a bright room"
                )
            }
            
            Spacer()
            
            Button(action: {
                showInstructionsSheet = false
                // Small delay to allow sheet to dismiss smoothly before opening camera
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStartScan()
                }
            }) {
                Text("Continue")
                    .font(AppTheme.buttonFont())
                    .foregroundColor(AppTheme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(AppTheme.limeAccent))
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func tipRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surfaceEmphasis)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.limeAccent)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    PostureScanIntroView(
        onStartScan: {},
        onSkip: {},
        onBack: {}
    )
}
