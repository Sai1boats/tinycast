import AppKit
import Carbon.HIToolbox

/// The always-on-top pomodoro widget; Esc collapses the expanded card back down.
final class PomodoroWidgetPanel: NSPanel, AnimatedPanel {
    var onEscape: (() -> Void)?

    init(content: NSView, cornerRadius: CGFloat) {
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        followMotion()
        isReleasedWhenClosed = false
        isRestorable = false
        content.wantsLayer = true
        content.layer?.cornerRadius = cornerRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        contentView = content
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, Int(event.keyCode) == kVK_Escape, !event.isARepeat else {
            super.sendEvent(event)
            return
        }
        onEscape?()
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
