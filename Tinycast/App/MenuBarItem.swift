import SwiftUI

/// Tinycast's own menu-bar item. It carries no feature state, so no feature can hide or reshape it.
struct MenuBarLabel: View {
    let appName: String

    var body: some View {
        Image("MenuBarIcon")
            .accessibilityLabel(appName)
    }
}

struct MenuBarMenu: View {
    let appName: String

    var body: some View {
        Button(String(localized: "Open \(appName)")) {
            AppCore.shared.paletteCoordinator.showPalette(mode: .launcher)
        }
        // Read through Observation, so switching the feature off takes the row with it.
        if AppCore.shared.settings.clipboardEnabled {
            Button(String(localized: "Clipboard History")) {
                AppCore.shared.paletteCoordinator.showPalette(mode: .clipboard)
            }
        }
        Divider()
        Button(String(localized: "Check for Updates...")) { AppCore.shared.updateCoordinator.checkForUpdates() }
        Button(String(localized: "Support \(appName)...")) { AppCore.shared.supportCoordinator.showSupport() }
        Button(String(localized: "Settings...")) { AppCore.shared.settingsCoordinator.showSettings() }
            .keyboardShortcut(",")
        Divider()
        // No ⌘Q: the app menu binds it to Close Settings, and two contradictory ⌘Qs is a lie.
        Button(String(localized: "Quit \(appName)")) { NSApp.terminate(nil) }
    }
}
