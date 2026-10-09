import AppKit

@MainActor
final class UtilityWindowChrome: WindowChrome {
    func install(in window: NSWindow) {
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
    }
}
