import SwiftUI

struct TodosSettingsView: View {
    @Environment(TodosCoordinator.self) private var todos
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Group {
            Section {
                Toggle(isOn: $settings.todosEnabled) {
                    SettingsFeatureToggleLabel(
                        anchor: .planoteTodos, title: "Enable Todos",
                        subtitle: enableSubtitle)
                }
            }
            .settingsAnchor(.planoteTodos)

            Section {
                LabeledContent {
                    Text(planoteState)
                } label: {
                    SettingsRowTitle(.planoteConnection, "Planote Connection")
                }
                LabeledContent {
                    Button(
                        String(localized: "Open Folder"),
                        action: todos.openBridgeFolder)
                } label: {
                    SettingsRowTitle(.planoteConnection, "Bridge Folder")
                    Text(bridgePath)
                }
                LabeledContent {
                    Text(lastHeartbeat)
                } label: {
                    SettingsRowTitle(.planoteConnection, "Last Heartbeat")
                }
                if let error = todos.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.destructive)
                }
            } header: {
                SettingsSectionHeader(.planoteConnection)
            }
            .settingsEnabled(settings.todosEnabled)

            FeatureCommandsSection(owner: .planote, anchor: .planoteCommands)
                .settingsEnabled(settings.todosEnabled)
        }
    }

    private var enableSubtitle: LocalizedStringResource {
        "Tasks mirrored from Planote. Tinycast starts it in the background."
    }

    private var planoteState: String {
        guard todos.isPlanoteInstalled else { return String(localized: "Not installed") }
        return todos.isPlanoteRunning
            ? String(localized: "Installed, running")
            : String(localized: "Installed, not running")
    }

    private var bridgePath: String {
        (todos.bridgeDirectoryPath as NSString).abbreviatingWithTildeInPath
    }

    private var lastHeartbeat: String {
        guard let heartbeat = todos.lastHeartbeat else {
            return String(localized: "Not yet")
        }
        return heartbeat.formatted(date: .abbreviated, time: .shortened)
    }
}
