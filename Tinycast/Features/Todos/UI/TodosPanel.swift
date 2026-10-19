import AppKit
import Carbon.HIToolbox

final class TodosPanel: NSPanel {
    var onEscape: (() -> Void)?
    /// The ⌘-letter chords this window claims, by lowercased character.
    var commandChords: [String: () -> Void] = [:]

    init(content: NSView, size: CGSize, styleMask: NSWindow.StyleMask) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask.union([.fullSizeContentView, .nonactivatingPanel]),
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        isReleasedWhenClosed = false
        isRestorable = false
        contentView = content
    }

    /// The main menu is offered chords first, so this is the fallback for a non-activating panel.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        guard !event.isARepeat, event.modifierFlags.intersection([.command, .option, .control])
            == .command
        else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased(),
            let chord = commandChords[key]
        else { return false }
        chord()
        return true
    }

    override func sendEvent(_ event: NSEvent) {
        // Escape reaches the editor even from a field, so a typed draft is left deliberately.
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
    override var canBecomeMain: Bool { true }
}
