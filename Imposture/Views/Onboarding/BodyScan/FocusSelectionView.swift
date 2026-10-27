//
//  FocusSelectionView.swift
//  Team-5
//
//  Figma Node: 2131:3220 & 2131:3244 ("Where would you like to focus?")
//  Interactive 2x2 grid for selecting posture focus areas.
//

import SwiftUI

struct FocusSelectionView: View {
    @Binding var selectedFocusAreas: Set<FocusArea>
    var onContinue: () -> Void
    var onSkip: () -> Void
    var onBack: () -> Void
    
    // Grid columns layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Bar
            HStack {
                CircleIconButton(systemImage: "chevron.left", label: "Back to name input", action: onBack)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where would you like\nto focus?")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Choose any that feel stiff or that you'd like to strengthen. You can change this later.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // MARK: - 2x2 Card Grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        focusCard(for: .humpNeck)
                        focusCard(for: .hunchBack)
                        focusCard(for: .techNeck)
                        focusCard(for: .roundedShoulders)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            
            // MARK: - Bottom Action Button
            VStack(spacing: 0) {
                if selectedFocusAreas.isEmpty {
                    AppButton("Skip for now", action: onSkip)
                        .accessibilityIdentifier("onboarding.skipFocus")
                } else {
                    AppButton("Continue", action: onContinue)
                        .accessibilityIdentifier("onboarding.continue")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
    
    // MARK: - Focus Card Component
    @ViewBuilder
    private func focusCard(for area: FocusArea) -> some View {
        let isSelected = selectedFocusAreas.contains(area)
        
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                if isSelected {
                    selectedFocusAreas.remove(area)
                } else {
                    selectedFocusAreas.insert(area)
                }
            }
        }) {
            VStack(spacing: 12) {
                // Card Surface & Illustration
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? AppTheme.limeAccentSoft : AppTheme.surface)
                    
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isSelected ? AppTheme.limeAccent : AppTheme.separator,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                    
                    if Artwork.showsIllustrations {
                        Image(area.imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                    } else {
                        Image(systemName: area.bodyArea.systemImage)
                            .font(.largeTitle.weight(.light))
                            .foregroundStyle(isSelected ? AppTheme.limeAccent : AppTheme.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .shadow(
                    color: isSelected ? AppTheme.limeAccent.opacity(0.15) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
                
                // Label
                Text(area.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(area.title) focus area")
        .accessibilityIdentifier("onboarding.focus.\(area.bodyArea.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selected: Set<FocusArea> = [.techNeck]
        var body: some View {
            FocusSelectionView(
                selectedFocusAreas: $selected,
                onContinue: {},
                onSkip: {},
                onBack: {}
            )
        }
    }
    return PreviewWrapper()
}
