//
//  ImpostureApp.swift
//  Imposture
//
//  Created by user@72 on 09/10/26.
//

import SwiftUI
import UIKit

@main
struct ImpostureApp: App {
    @State private var appModel: AppModel

    init() {
        #if DEBUG
        // UI tests can launch with the in-memory preview store, so data screens have content
        // without touching what's saved on the device.
        if CommandLine.arguments.contains("-previewData") {
            _appModel = State(initialValue: .preview())
            return
        }
        #endif

        // UI tests launch with a clean, throwaway state.
        let isUITesting = CommandLine.arguments.contains("-uiTestingReset")
        if isUITesting, let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        // If the store can't be opened the app still works; Progress explains the problem.
        let container = try? SwiftDataSessionHistoryStore.makeContainer(inMemory: isUITesting)
        _appModel = State(initialValue: AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: UserDefaultsPreferencesStore(),
            historyStore: container.map(SwiftDataSessionHistoryStore.init(container:)),
            snapshotStore: UserDefaultsSnapshotStore(),
            assessmentStore: container.map(SwiftDataPostureAssessmentStore.init(container:)),
            reminders: LocalReminderService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
    }
}
