import AppKit
import SwiftUI

@MainActor
final class PomodoroWidgetController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "Pomodoro Widget"

    private unowned let coordinator: PomodoroCoordinator
    private unowned let core: AppCore
    private let settings: AppSettings
    private var panel: PomodoroWidgetPanel?

    init(coordinator: PomodoroCoordinator, core: AppCore, settings: AppSettings) {
        self.coordinator = coordinator
        self.core = core
        self.settings = settings
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(expanded: Bool) {
        let panel = ensurePanel()
        resize(panel, to: expanded)
        panel.orderFrontRegardless()
        // The corner is clipped in SwiftUI, so the shadow has to be recut from what was drawn.
        panel.invalidateShadow()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Keeps the top-left corner put so the card grows and shrinks downward in place.
    func resizeToCurrentFace() {
        guard let panel else { return }
        resize(panel, to: coordinator.isExpanded)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        coordinator.hideWidget()
    }

    // MARK: - Private

    private func resize(_ panel: NSWindow, to expanded: Bool) {
        let size = expanded ? Theme.Size.pomodoroExpanded : Theme.Size.pomodoroCollapsed
        var frame = panel.frame
        let top = frame.maxY
        frame.size = size
        frame.origin.y = top - size.height
        frame = onScreen(frame)
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    /// A display change can restore the autosaved frame outside every screen; keep the card reachable.
    private func onScreen(_ frame: NSRect) -> NSRect {
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        let visible = (NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main)?
            .visibleFrame
        guard let visible else { return frame }
        guard visible.intersects(frame) else {
            return NSRect(
                x: visible.maxX - frame.width, y: visible.maxY - frame.height,
                width: frame.width, height: frame.height)
        }
        var clamped = frame
        clamped.origin.x = min(max(clamped.origin.x, visible.minX), visible.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.origin.y, visible.minY), visible.maxY - clamped.height)
        return clamped
    }

    private func ensurePanel() -> PomodoroWidgetPanel {
        if let panel { return panel }
        let root = PomodoroWidgetView()
            .environment(coordinator)
            .environment(core)
            .environment(settings)
        let hosting = PomodoroHostingView(rootView: root)
        hosting.sizingOptions = []
        let panel = PomodoroWidgetPanel(
            content: hosting, cornerRadius: Theme.Radius.utilityWindow)
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.coordinator.collapseWidget() }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            seatFirstShow(of: panel)
        }
        resize(panel, to: coordinator.isExpanded)
        self.panel = panel
        return panel
    }

    private func seatFirstShow(of panel: NSWindow) {
        let size = Theme.Size.pomodoroCollapsed
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }
        let seat = NoteWindowPlacement.topRight(
            NSRect(origin: .zero, size: size), in: visibleFrame, inset: Theme.Spacing.xxxl)
        panel.setFrame(seat, display: false)
    }
}

/// Takes the first click while the app is inactive, so one click always acts.
private final class PomodoroHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
