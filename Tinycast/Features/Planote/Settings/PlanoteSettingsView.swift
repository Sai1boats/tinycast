import SwiftUI

struct PlanoteSettingsView: View {
    @Environment(PlanoteCoordinator.self) private var planote
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle(isOn: $settings.planoteNotesEnabled) {
                    SettingsFeatureToggleLabel(
                        anchor: .planoteNotes, title: "Search Planote Notes",
                        subtitle: "Find notes by title in the launcher, then read and edit them here.")
                }
                LabeledContent("Indexed Notes", value: "\(planote.notes.count)")
            }
            .settingsAnchor(.planoteNotes)
            Section {
                LabeledContent("Status", value: status)
                Text("The background service has no window or Dock icon. Stopping it pauses writes for notes and todos.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Start Service") { Task { await planote.startService() } }
                        .disabled(planote.isWorking || !planote.isInstalled)
                    Button("Stop Service") { Task { await planote.stopService() } }
                        .disabled(planote.isWorking || (!planote.isRunning && !settings.planoteServiceEnabled))
                    Spacer()
                    Button("Open Planote", action: planote.openPlanote).disabled(!planote.isInstalled)
                }
                if let error = planote.errorMessage {
                    Text(error).foregroundStyle(Theme.Colors.destructive)
                }
            } header: { SettingsSectionHeader(.planoteService) }
            .settingsAnchor(.planoteService)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.planote)
        .task {
            while !Task.isCancelled {
                planote.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    private var status: String {
        if !planote.isInstalled { return String(localized: "Not installed") }
        if planote.isWorking { return String(localized: "Working…") }
        return planote.isRunning ? String(localized: "Running") : String(localized: "Stopped")
    }
}
