import AppKit
import SwiftUI

struct UtilityTextEditor: NSViewRepresentable {
    @Binding var text: String
    let editable: Bool
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = Editor()
        editor.isRichText = false
        editor.isEditable = editable
        editor.isSelectable = true
        editor.allowsUndo = editable
        editor.drawsBackground = false
        editor.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.textContainerInset = NSSize(width: Theme.Spacing.md, height: Theme.Spacing.md)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = .width
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel(label)
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text {
            editor.string = text
            editor.undoManager?.removeAllActions()
        }
    }

    private final class Editor: NSTextView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if isEditable { window?.makeFirstResponder(self) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UtilityTextEditor
        init(_ parent: UtilityTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, parent.editable else { return }
            parent.text = editor.string
        }
    }
}
