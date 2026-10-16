import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private var panel: TranslationPanel?
    private weak var coordinator: TranslationCoordinator?
    private var collapsedFrame: NSRect?

    func show(_ coordinator: TranslationCoordinator) {
        if let panel { panel.makeKeyAndOrderFront(nil); return }
        self.coordinator = coordinator
        let hosting = NSHostingView(rootView: TranslationPanelView().environment(coordinator))
        hosting.sizingOptions = []
        let panel = TranslationPanel(
            contentRect: NSRect(origin: .zero, size: Theme.Size.translationPanel),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.setContentSize(Theme.Size.translationPanel)
        panel.minSize = Theme.Size.translationMinimum
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.delegate = self
        panel.onEscape = { [weak coordinator] in coordinator?.close() }
        self.panel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func focus() { panel?.makeKeyAndOrderFront(nil) }

    /// Long text gets most of the screen; collapsing returns to wherever the reader left it.
    func setExpanded(_ expanded: Bool) -> Bool {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return false }
        if expanded {
            collapsedFrame = panel.frame
            let visible = screen.visibleFrame
            let size = NSSize(
                width: max(visible.width * Theme.Size.translationExpandedFraction, panel.minSize.width),
                height: max(visible.height * Theme.Size.translationExpandedFraction, panel.minSize.height))
            let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
            panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
            return true
        }
        if let collapsedFrame { panel.setFrame(collapsedFrame, display: true, animate: true) }
        collapsedFrame = nil
        return false
    }

    func dismiss() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
        coordinator = nil
        collapsedFrame = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let coordinator, !coordinator.isPinned, !coordinator.showsSettings,
            !coordinator.isLoading, !coordinator.isReadingSelection
        else { return }
        coordinator.close()
    }

    private final class TranslationPanel: NSPanel {
        var onEscape: (() -> Void)?
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        override func cancelOperation(_ sender: Any?) { onEscape?() }
    }
}
