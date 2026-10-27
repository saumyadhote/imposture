// Ported from the vyam onboarding (Team-5): splash, three slides, name, focus areas,
// the body scan and its results. Hands the name and focus areas back when it finishes.

import SwiftUI

struct OnboardingContainerView: View {
    /// Called once, with the name (nil if none was given) and the chosen focus areas.
    var onComplete: (_ name: String?, _ focus: Set<FocusArea>) -> Void
    
    @State private var currentStep: OnboardingStep = .splash
    @State private var carouselPage: Int = 0
    @State private var tempName: String = ""
    @State private var selectedFocusAreas: Set<FocusArea> = [.techNeck, .roundedShoulders]
    @State private var baselineAssessment = BaselineAssessment()
    
    private let totalSlides = OnboardingContent.slides.count
    
    var body: some View {
        ZStack {
            switch currentStep {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .carousel(page: 0)
                    }
                }
                .transition(.opacity)
                
            case .carousel:
                VStack(spacing: 0) {
                    // MARK: - Swipeable Slides (Matching Figma Screens 01, 02, 03)
                    TabView(selection: $carouselPage) {
                        ForEach(OnboardingContent.slides) { slide in
                            OnboardingSlideView(slide: slide)
                                .tag(slide.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: carouselPage)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width < -40 && carouselPage == totalSlides - 1 {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        currentStep = .nameInput
                                    }
                                }
                            }
                    )
                    
                    // MARK: - Fixed Bottom 3-Dot Pager (Exact Figma node layout)
                    HStack(spacing: 8) {
                        ForEach(0..<totalSlides, id: \.self) { index in
                            Circle()
                                .fill(carouselPage == index ? AppTheme.dotActive : AppTheme.dotInactive)
                                .frame(width: 8, height: 8)
                                .contentShape(Rectangle().inset(by: -6))
                                .accessibilityLabel("Slide \(index + 1) of \(totalSlides)")
                                .accessibilityAddTraits(carouselPage == index ? [.isSelected] : [])
                                .onTapGesture {
                                    if carouselPage == index && index == totalSlides - 1 {
                                        withAnimation(.easeInOut(duration: 0.28)) {
                                            currentStep = .nameInput
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            carouselPage = index
                                        }
                                    }
                                }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Slide position: \(carouselPage + 1) of \(totalSlides)")
                    .frame(height: 36)

                    AppButton(carouselPage == totalSlides - 1 ? "Get Started" : "Next") {
                        if carouselPage < totalSlides - 1 {
                            withAnimation(.easeOut(duration: 0.25)) { carouselPage += 1 }
                        } else {
                            withAnimation(.easeInOut(duration: 0.28)) { currentStep = .nameInput }
                        }
                    }
                    .accessibilityIdentifier("onboarding.next")
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.bottom, Spacing.lg)
                }
                .transition(.opacity)
                
            case .nameInput:
                NameInputView(
                    name: $tempName,
                    onNext: {
                        tempName = UserNameValidator.sanitize(tempName)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .focusSelection
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = .carousel(page: totalSlides - 1)
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .focusSelection:
                FocusSelectionView(
                    selectedFocusAreas: $selectedFocusAreas,
                    onContinue: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .scanIntro
                        }
                    },
                    onSkip: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .scanIntro
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = .nameInput
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .scanIntro:
                PostureScanIntroView(
                    onStartScan: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .scanCapture(angle: .front)
                        }
                    },
                    onSkip: {
                        baselineAssessment = .skipped(focus: selectedFocusAreas)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .baselineResults
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = .focusSelection
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .scanCapture:
                PostureScanView(
                    onScanCompleted: { scanData in
                        baselineAssessment = .generate(from: selectedFocusAreas, scanData: scanData)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .baselineResults
                        }
                    },
                    onSkip: {
                        baselineAssessment = .skipped(focus: selectedFocusAreas)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = .baselineResults
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = .scanIntro
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .baselineResults:
                BaselineResultsView(
                    assessment: baselineAssessment,
                    onBuildPlan: finish
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .completed:
                Color.clear
                    .onAppear(perform: finish)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func finish() {
        guard currentStep != .completed else { return }
        currentStep = .completed
        onComplete(tempName.isEmpty ? nil : tempName, selectedFocusAreas)
    }
}

#Preview {
    OnboardingContainerView { _, _ in }
}
