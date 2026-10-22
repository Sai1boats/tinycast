import AppKit
import SwiftUI

@MainActor
final class TodosWindowController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "Todos Window"

    private unowned let coordinator: TodosCoordinator
    private unowned let core: AppCore
    private let settings: AppSettings
    private var panel: TodosPanel?

    init(coordinator: TodosCoordinator, core: AppCore, settings: AppSettings) {
        self.coordinator = coordinator
        self.core = core
        self.settings = settings
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(focus: Bool) {
        let panel = ensurePanel()
        panel.contentView?.layoutSubtreeIfNeeded()
        if focus {
            panel.makeKeyAndOrderFront(nil)
            if !coordinator.isShowingEditor {
                panel.makeFirstResponder(nil)
            }
        }
        panel.orderFrontRegardless()
        seatTrafficLights(in: panel)
        // The corner is clipped in SwiftUI, so the shadow has to be recut from what was drawn.
        panel.invalidateShadow()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    /// The red button and ⌘W both arrive here, so closing is one path and never destroys state.
    func windowWillClose(_ notification: Notification) {
        coordinator.hide()
    }

    /// `contentMinSize` alone leaks frames below it; AppKit takes whatever this returns verbatim.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: max(frameSize.width, Theme.Size.todosWindowMinimum.width),
            height: max(frameSize.height, Theme.Size.todosWindowMinimum.height))
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel else { return }
        seatTrafficLights(in: panel)
    }

    func windowDidUpdate(_ notification: Notification) {
        guard let panel else { return }
        seatTrafficLights(in: panel)
    }

    // MARK: - Private

    private func ensurePanel() -> TodosPanel {
        if let panel { return panel }
        let root = TodosView()
            .environment(coordinator)
            .environment(core)
            .environment(settings)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        let panel = TodosPanel(
            content: hosting,
            size: Theme.Size.todosWindow,
            styleMask: [.titled, .closable, .miniaturizable, .resizable])
        // `TodosView` draws its own band, so AppKit keeps its centred title and inset out of it.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.contentMinSize = Theme.Size.todosWindowMinimum
        panel.delegate = self
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if coordinator.isShowingEditor {
                coordinator.cancelEditing()
            } else {
                coordinator.hide()
            }
        }
        panel.commandChords = [
            "w": { [weak panel] in panel?.performClose(nil) }
        ]
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            seatFirstShow(of: panel)
        }
        panel.setContentSize(
            CGSize(
                width: max(panel.frame.width, Theme.Size.todosWindowMinimum.width),
                height: max(panel.frame.height, Theme.Size.todosWindowMinimum.height)))
        if let close = panel.standardWindowButton(.closeButton) {
            close.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(trafficLightFrameDidChange),
                name: NSView.frameDidChangeNotification, object: close)
        }
        self.panel = panel
        return panel
    }

    private func seatFirstShow(of panel: NSWindow) {
        guard let visibleFrame = (NSScreen.main)?.visibleFrame else {
            panel.center()
            return
        }
        let seat = NoteWindowPlacement.topRight(
            NSRect(origin: .zero, size: Theme.Size.todosWindow),
            in: visibleFrame,
            inset: Theme.Spacing.xxxl)
        panel.setFrame(seat, display: false)
    }

    /// Idempotent, because AppKit re-seats the lights on a resize and on every title assignment.
    private func seatTrafficLights(in window: NSWindow) {
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
            .compactMap(window.standardWindowButton)
        guard let leading = buttons.first, let band = leading.superview?.bounds.height
        else { return }
        // Centred in the drawn band, not AppKit's shorter one, and clamped so none is clipped.
        let size = leading.frame.height
        let y = max(0, band - size - (Theme.Size.todosTitlebar - size) / 2)
        let shift = Theme.Size.todosTrafficLightInset - leading.frame.minX
        guard shift != 0 || leading.frame.origin.y != y else { return }
        for button in buttons {
            button.frame.origin.x += shift
            button.frame.origin.y = y
        }
    }

    @objc private func trafficLightFrameDidChange(_ notification: Notification) {
        // AppKit can finish laying out the traffic lights after posting the frame change.
        Task { @MainActor [weak self] in
            guard let self, let panel else { return }
            seatTrafficLights(in: panel)
        }
    }
}
