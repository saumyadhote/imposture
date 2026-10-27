//
//  OnboardingSlideView.swift
//  Team-5
//
//  Lightweight, memory-efficient presentation for individual onboarding slides.
//

import SwiftUI

struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            
            // MARK: - Illustration
            OnboardingArt(name: slide.imageName, label: "Illustration placeholder", height: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            
            Spacer(minLength: 16)
            
            // MARK: - Text Content
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(AppTheme.titleFont())
                    .foregroundColor(AppTheme.limeAccent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHeading(.h1)
                
                Text(slide.description)
                    .font(AppTheme.bodyFont())
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 340)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 16)
        }
    }
}

#Preview("Slide 1") {
    OnboardingSlideView(slide: OnboardingData.slides[0])
        .background(AppTheme.background)
}

#Preview("Slide 2") {
    OnboardingSlideView(slide: OnboardingData.slides[1])
        .background(AppTheme.background)
}

#Preview("Slide 3") {
    OnboardingSlideView(slide: OnboardingData.slides[2])
        .background(AppTheme.background)
}
