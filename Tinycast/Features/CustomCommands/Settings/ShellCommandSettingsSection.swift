import SwiftUI

struct ShellCommandSettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var installed: [ShellCommandDestination] = [.tinycast]

    private var destinations: [ShellCommandDestination] {
        ShellCommandDestination.allCases.filter {
            installed.contains($0) || $0 == settings.shellCommandDestination
        }
    }

    var body: some View {
        @Bindable var settings = settings
        Section {
            Picker(selection: $settings.shellCommandDestination) {
                ForEach(destinations) { destination in
                    Text(label(for: destination))
                        .tag(destination)
                        .disabled(!installed.contains(destination))
                }
            } label: {
                SettingsRowTitle(.commandsShellCommand, "Execute in")
            }
        } header: {
            SettingsSectionHeader(.commandsShellCommand)
        } footer: {
            VStack(alignment: .leading) {
                Text(String(localized: "Applies to Run Shell Command and # followed by a space."))
                Text(String(localized: "Terminal sessions stay open for further commands."))
                if settings.shellCommandDestination == .iterm {
                    Text(String(localized: "Choose a new window or tab in iTerm’s command confirmation page."))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onAppear { installed = TerminalCommandRunner.installedDestinations }
    }

    private func label(for destination: ShellCommandDestination) -> String {
        let name = NSLocalizedString(destination.name, comment: "Shell command destination")
        return installed.contains(destination) ? name : String(localized: "\(name) (Not installed)")
    }
}
