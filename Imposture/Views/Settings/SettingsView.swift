import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel?
    @State private var isConfirmingReset = false
    /// False when shown as a tab, where there is nothing to dismiss.
    var showsDoneButton = true

    var body: some View {
        NavigationStack {
            Form {
                routineSection
                reminderSection
                aboutSection
                resetSection
            }
            .scrollContentBackground(.hidden)
            .impostureScreenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Reset all progress?", isPresented: $isConfirmingReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset progress", role: .destructive) { appModel.resetProgress() }
            } message: {
                Text("This permanently removes your session history from this iPhone. Your preferences stay the same.")
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = SettingsViewModel(appModel: appModel) }
        }
    }

    private var routineSection: some View {
        Section {
            Picker("Position", selection: preferenceBinding(\.positionPreference)) {
                ForEach(PositionPreference.allCases) { Text($0.title).tag($0) }
            }
            Picker("Session length", selection: preferenceBinding(\.sessionLength)) {
                ForEach(SessionLength.allCases) { Text($0.title).tag($0) }
            }
            NavigationLink {
                FocusAreasSettingsView()
            } label: {
                LabeledContent("Focus areas", value: focusSummary)
            }
        } header: {
            Text("Your sessions")
        } footer: {
            Text("Used to choose today's suggested session.")
        }
        .listRowBackground(Color.impostureSurface)
    }

    private var reminderSection: some View {
        Section {
            Toggle("Daily reminder", isOn: reminderToggle)
                .tint(Color.impostureAccentFill)
                .disabled(viewModel?.isUpdatingReminder ?? true)
                .accessibilityIdentifier("settings.reminderToggle")
            if appModel.preferences.remindersEnabled {
                DatePicker("Time", selection: reminderDate, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Reminders")
        } footer: {
            if let message = viewModel?.reminderMessage {
                Text(message)
            }
        }
        .listRowBackground(Color.impostureSurface)
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("Safety and guidance") { SafetyInfoView() }
            LabeledContent("Content", value: "Draft, pending professional review")
        }
        .listRowBackground(Color.impostureSurface)
    }

    private var resetSection: some View {
        Section {
            Button {
                dismiss()
                appModel.replayOnboarding()
            } label: {
                Label("Replay onboarding & body scan", systemImage: "figure.stand")
            }
            .accessibilityHint("Runs onboarding again. Your progress is kept.")
            .accessibilityIdentifier("settings.replayOnboarding")
            Button("Reset progress", role: .destructive) { isConfirmingReset = true }
                .disabled(appModel.history.isEmpty)
        }
        .listRowBackground(Color.impostureSurface)
    }

    // MARK: - Bindings

    private var focusSummary: String {
        let areas = BodyArea.allCases.filter(appModel.preferences.focusAreas.contains)
        return areas.isEmpty ? "None" : areas.map(\.title).joined(separator: ", ")
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding {
            appModel.preferences[keyPath: keyPath]
        } set: { newValue in
            appModel.updatePreferences { $0[keyPath: keyPath] = newValue }
        }
    }

    private var reminderToggle: Binding<Bool> {
        Binding {
            appModel.preferences.remindersEnabled
        } set: { enabled in
            Task { await viewModel?.setRemindersEnabled(enabled) }
        }
    }

    private var reminderDate: Binding<Date> {
        Binding {
            let time = appModel.preferences.reminderTime
            return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let time = ReminderTime(hour: parts.hour ?? 11, minute: parts.minute ?? 0)
            Task { await viewModel?.setReminderTime(time) }
        }
    }
}

private struct FocusAreasSettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(BodyArea.allCases) { area in
                    SelectableRow(
                        title: area.title,
                        systemImage: area.systemImage,
                        imageName: area.artworkName,
                        isSelected: appModel.preferences.focusAreas.contains(area)
                    ) {
                        appModel.updatePreferences { preferences in
                            if preferences.focusAreas.contains(area) {
                                preferences.focusAreas.remove(area)
                            } else {
                                preferences.focusAreas.insert(area)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.screenMargin)
        }
        .impostureScreenBackground()
        .navigationTitle("Focus areas")
        .sensoryFeedback(.selection, trigger: appModel.preferences.focusAreas)
    }
}

private struct SafetyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SafetyParagraph(
                    title: "General guidance, not medical advice",
                    text: "imposture offers general movement suggestions. It does not diagnose, treat or prevent any condition."
                )
                SafetyParagraph(
                    title: "Move comfortably",
                    text: "Work within a range that feels comfortable. Mild stretching is normal; sharp pain, dizziness, numbness or tingling are signs to stop."
                )
                SafetyParagraph(
                    title: "Check first if you need to",
                    text: "If you have an injury, a health condition, or have had recent surgery, talk to your doctor or physiotherapist before starting."
                )
                SafetyParagraph(
                    title: "Use stable support",
                    text: "Use a sturdy chair that won't roll or tip, and keep something to hold nearby for standing exercises."
                )
                SafetyParagraph(
                    title: "About the exercise content",
                    text: "The exercise instructions in this version are a draft and are pending review by a qualified professional."
                )
            }
            .padding(Spacing.screenMargin)
        }
        .impostureScreenBackground()
        .navigationTitle("Safety and guidance")
    }
}

private struct SafetyParagraph: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.impostureTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.impostureTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview())
}
