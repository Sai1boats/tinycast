import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private var panel: TranslationPanel?
    private weak var coordinator: TranslationCoordinator?

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

    func dismiss() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
        coordinator = nil
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
