import AppKit
import SwiftUI

struct TranslationTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let onSubmit: () -> Void
    let onHistory: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = Editor()
        editor.isRichText = false
        editor.drawsBackground = false
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.textContainerInset = NSSize(width: 0, height: Theme.Spacing.sm)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = .width
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.delegate = context.coordinator
        editor.onHistory = onHistory
        editor.setAccessibilityLabel(String(localized: "Source text"))
        editor.apply(fontSize: fontSize)
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? Editor else { return }
        if editor.string != text { editor.string = text }
        if editor.font?.pointSize != fontSize { editor.apply(fontSize: fontSize) }
        editor.onHistory = onHistory
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationTextEditor
        init(_ parent: TranslationTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() else {
                return false
            }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertText("\n", replacementRange: textView.selectedRange())
            } else {
                parent.onSubmit()
            }
            return true
        }
    }

    private final class Editor: NSTextView {
        var onHistory: ((Bool) -> Void)?

        func apply(fontSize: CGFloat) {
            let font = NSFont.systemFont(ofSize: fontSize)
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = Theme.Size.translationLineHeight
            self.font = font
            defaultParagraphStyle = style
            typingAttributes = [.font: font, .paragraphStyle: style, .foregroundColor: NSColor.labelColor]
            guard let storage = textStorage, storage.length > 0 else { return }
            let range = NSRange(location: 0, length: storage.length)
            storage.addAttributes([.font: font, .paragraphStyle: style], range: range)
        }

        override func keyDown(with event: NSEvent) {
            if !hasMarkedText(), event.modifierFlags.intersection([.command, .option, .control, .shift]) == .option,
                event.keyCode == 126 || event.keyCode == 125 {
                onHistory?(event.keyCode == 126)
                return
            }
            super.keyDown(with: event)
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
    }
}
