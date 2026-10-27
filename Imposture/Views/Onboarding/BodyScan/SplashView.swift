//
//  SplashView.swift
//  Team-5
//
//  Screen 1: Minimal dark background matching Figma node 2131-2979.
//

import SwiftUI

struct SplashView: View {
    var onContinue: () -> Void
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                BrandMark()

                Spacer()

                Text("Tap to begin")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.bottom, Spacing.xl)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onContinue()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("imposture. Begin")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onContinue() }
        .accessibilityIdentifier("onboarding.start")
    }
}
