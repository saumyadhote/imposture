//
//  NameInputView.swift
//  Team-5
//
//  Screen 4: "What should we call you?" (Figma node 2131-2996).
//

import SwiftUI

struct NameInputView: View {
    @Binding var name: String
    var onNext: () -> Void
    var onBack: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    private var isNameValid: Bool {
        UserNameValidator.isValid(name)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
                .onTapGesture {
                    isFocused = false
                }
            
            VStack(spacing: 0) {
                // MARK: - Back Navigation Bar
                HStack {
                    if let onBack = onBack {
                        CircleIconButton(systemImage: "chevron.left", label: "Go back", action: onBack)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // MARK: - Top Illustration
                OnboardingArt(name: "onboarding_name", label: "Greeting illustration placeholder", height: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                
                Spacer(minLength: 16)
                
                // MARK: - Title
                Text("What should we call you?")
                    .font(AppTheme.titleFont())
                    .foregroundColor(AppTheme.limeAccent)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 20)
                    .accessibilityHeading(.h1)
                
                Spacer(minLength: 20)
                
                // MARK: - Text Field Pill (Figma style)
                HStack(spacing: 12) {
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("Your Name").foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    )
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(AppTheme.textPrimary)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityLabel("Your Name")
                    .accessibilityIdentifier("onboarding.name")
                    .accessibilityHint("Enter your name to personalize your posture experience")
                    .onSubmit {
                        if isNameValid {
                            name = UserNameValidator.sanitize(name)
                            onNext()
                        }
                    }
                    
                    if !name.isEmpty {
                        Button(action: { name = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear name text")
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 320)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(AppTheme.surface)
                )
                
                Spacer(minLength: 28)
                
                // MARK: - Bottom Action
                HStack {
                    AppButton("Next") {
                        isFocused = false
                        name = UserNameValidator.sanitize(name)
                        onNext()
                    }
                    .disabled(!isNameValid)
                    .accessibilityLabel("Next step")
                    .accessibilityIdentifier("onboarding.nameNext")
                    .accessibilityHint(isNameValid ? "Continues to focus area selection" : "Disabled until you enter a valid name")
                    .animation(.easeInOut(duration: 0.2), value: isNameValid)
                }
                .padding(.trailing, 28)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview("Name Input Screen") {
    struct PreviewWrapper: View {
        @State var name = "Your Name"
        var body: some View {
            NameInputView(name: $name, onNext: {}, onBack: {})
        }
    }
    return PreviewWrapper()
}
