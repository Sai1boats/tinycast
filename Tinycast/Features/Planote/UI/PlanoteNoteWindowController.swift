import AppKit
import SwiftUI

@MainActor
final class PlanoteNoteWindowController: NSObject, NSWindowDelegate {
    private unowned let coordinator: PlanoteCoordinator
    private let settings: AppSettings
    private var panel: NotesPanel?

    init(coordinator: PlanoteCoordinator, settings: AppSettings) {
        self.coordinator = coordinator
        self.settings = settings
    }

    func show() {
        if panel == nil {
            let hosting = NSHostingView(rootView: PlanoteNoteView().environment(coordinator).environment(settings))
            hosting.sizingOptions = []
            let panel = NotesPanel(
                content: hosting, size: NSSize(width: 660, height: 580),
                styleMask: [.titled, .closable, .resizable, .miniaturizable], acceptsMain: true)
            panel.title = "Planote"
            panel.contentMinSize = NSSize(width: 440, height: 350)
            panel.titlebarAppearsTransparent = true
            panel.delegate = self
            panel.onEscape = { [weak coordinator] in coordinator?.hide() }
            panel.commandChords = [
                "w": { [weak coordinator] in coordinator?.hide() },
                "s": { [weak coordinator] in coordinator?.session?.scheduleSave(immediately: true) }
            ]
            panel.setFrameAutosaveName("Planote Note")
            if !panel.setFrameUsingName("Planote Note") { panel.center() }
            self.panel = panel
        }
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
    func windowWillClose(_ notification: Notification) { coordinator.hide() }
}
