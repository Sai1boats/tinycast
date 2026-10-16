import AppKit
import SwiftUI

struct UtilityTextEditor: NSViewRepresentable {
    @Binding var text: String
    let editable: Bool
    let label: String
    var showsDiff = false

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
        editor.font = Theme.Typography.utilityEditorNSFont
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.textContainerInset = NSSize(width: Theme.Spacing.xl, height: Theme.Spacing.md)
        editor.textContainer?.lineFragmentPadding = 0
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
        if editor.string != text || context.coordinator.renderedDiff != showsDiff {
            editor.string = text
            editor.undoManager?.removeAllActions()
            if showsDiff { colorDifferences(in: editor) }
            context.coordinator.renderedDiff = showsDiff
        }
    }

    private func colorDifferences(in editor: NSTextView) {
        guard let storage = editor.textStorage else { return }
        let source = editor.string as NSString
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: source.length))
        var offset = 0
        while offset < source.length {
            let range = source.lineRange(for: NSRange(location: offset, length: 0))
            let line = source.substring(with: range)
            if line.hasPrefix("+ ") || line.hasPrefix("- ") {
                let color = line.hasPrefix("+ ") ? Theme.Colors.utilityDiffAdded : Theme.Colors.utilityDiffRemoved
                storage.addAttribute(.foregroundColor, value: NSColor(color), range: range)
            }
            offset = NSMaxRange(range)
        }
        storage.endEditing()
    }

    private final class Editor: NSTextView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if isEditable { window?.makeFirstResponder(self) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UtilityTextEditor
        var renderedDiff = false
        init(_ parent: UtilityTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, parent.editable else { return }
            parent.text = editor.string
        }
    }
}
