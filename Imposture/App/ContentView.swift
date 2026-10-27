//
//  ContentView.swift
//  Imposture
//
//  Created by user@72 on 09/10/26.
//

import SwiftUI

/// Root: loads content, then shows onboarding or the main tabs.
/// The session player is presented here so any screen can start one.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        content
            .tint(Color.impostureAccentText)
            // Dark by default; every token also has a light value if this is ever lifted.
            .preferredColorScheme(.dark)
            .task { appModel.load() }
            .fullScreenCover(item: $appModel.activeSession) { session in
                SessionView(session: session)
            }
            // The chosen session starts once the sheet has fully gone.
            .sheet(item: $appModel.recoveryOffer, onDismiss: appModel.recoverySheetDismissed) { offer in
                RecoverySheet(offer: offer)
            }
    }

    @ViewBuilder private var content: some View {
        switch appModel.loadState {
        case .loading:
            ProgressView("Loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .impostureScreenBackground()
        case .failed(let message):
            StateMessage(
                title: "Something went wrong",
                message: message,
                systemImage: "exclamationmark.triangle"
            ) {
                Button("Try again") { appModel.load() }
                    .buttonStyle(.imposturePrimary)
            }
            .frame(maxHeight: .infinity)
            .impostureScreenBackground()
        case .loaded:
            if appModel.preferences.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView { name, focus in
                    var draft = appModel.preferences
                    draft.name = name
                    draft.focusAreas = Set(focus.map(\.bodyArea))
                    appModel.completeOnboarding(with: draft)
                }
            }
        }
    }
}

#Preview("Main") {
    ContentView()
        .environment(AppModel.preview())
}

#Preview("Onboarding") {
    ContentView()
        .environment(AppModel.preview(onboarded: false))
}
