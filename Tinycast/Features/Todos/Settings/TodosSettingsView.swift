import SwiftUI

struct TodosSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Toggle(isOn: $settings.todosEnabled) {
                    SettingsFeatureToggleLabel(
                        anchor: .todosTodos, title: "Enable Todos",
                        subtitle: enableSubtitle)
                }
            }
            .settingsAnchor(.todosTodos)

            Section {
                LabeledContent {
                    Text(planoteState)
                } label: {
                    SettingsRowTitle(.todosOptions, "Planote Connection")
                }
                LabeledContent {
                    Button(
                        String(localized: "Open Folder"),
                        action: core.todosCoordinator.openBridgeFolder)
                } label: {
                    SettingsRowTitle(.todosOptions, "Bridge Folder")
                    Text(bridgePath)
                }
                LabeledContent {
                    Text(lastHeartbeat)
                } label: {
                    SettingsRowTitle(.todosOptions, "Last Heartbeat")
                }
                if let error = core.todosCoordinator.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.destructive)
                }
            } header: {
                SettingsSectionHeader(.todosOptions)
            }
            .settingsEnabled(settings.todosEnabled)

            FeatureCommandsSection(owner: .todos, anchor: .todosCommands)
                .settingsEnabled(settings.todosEnabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.todos)
        .task {
            guard settings.todosEnabled else { return }
            await core.todosCoordinator.refresh()
        }
    }

    private var enableSubtitle: LocalizedStringResource {
        "Tasks mirrored from Planote. Tinycast starts it in the background."
    }

    private var planoteState: String {
        let todos = core.todosCoordinator
        guard todos.isPlanoteInstalled else { return String(localized: "Not installed") }
        return todos.isPlanoteRunning
            ? String(localized: "Installed, running")
            : String(localized: "Installed, not running")
    }

    private var bridgePath: String {
        (core.todosCoordinator.bridgeDirectoryPath as NSString).abbreviatingWithTildeInPath
    }

    private var lastHeartbeat: String {
        guard let heartbeat = core.todosCoordinator.lastHeartbeat else {
            return String(localized: "Not yet")
        }
        return heartbeat.formatted(date: .abbreviated, time: .shortened)
    }
}
