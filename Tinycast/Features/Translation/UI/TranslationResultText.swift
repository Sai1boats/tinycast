import AppKit
import SwiftUI

/// Read-only and native, so a long translation selects, scrolls and copies like any document.
struct TranslationResultText: NSViewRepresentable {
    let paragraphs: [TranslationResult.Paragraph]
    let bilingual: Bool
    let fontSize: CGFloat

    final class Coordinator {
        var rendered: (paragraphs: [TranslationResult.Paragraph], bilingual: Bool, fontSize: CGFloat)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 0, height: Theme.Spacing.sm)
        view.textContainer?.lineFragmentPadding = 0
        view.setAccessibilityLabel(String(localized: "Translation"))
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, let storage = view.textStorage else { return }
        let previous = context.coordinator.rendered
        if let previous, previous.paragraphs == paragraphs, previous.bilingual == bilingual,
            previous.fontSize == fontSize
        {
            return
        }
        context.coordinator.rendered = (paragraphs, bilingual, fontSize)
        storage.setAttributedString(Self.render(paragraphs, bilingual: bilingual, fontSize: fontSize))
        // A long text arrives chunk by chunk; the reader keeps their place while it grows.
        let grows = previous.map { !$0.paragraphs.isEmpty && paragraphs.starts(with: $0.paragraphs) } ?? false
        if !grows { view.scroll(.zero) }
    }

    private static func render(
        _ paragraphs: [TranslationResult.Paragraph], bilingual: Bool, fontSize: CGFloat
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Theme.Size.translationLineHeight
        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize), .paragraphStyle: style,
            .foregroundColor: NSColor(Theme.Colors.textPrimary)
        ]
        guard bilingual else {
            return NSAttributedString(string: paragraphs.map(\.text).joined(separator: "\n"), attributes: body)
        }
        let source: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(fontSize - 2, Theme.Size.translationTextMinimum)),
            .paragraphStyle: style, .foregroundColor: NSColor(Theme.Colors.textSecondary)
        ]
        let spaced = NSMutableParagraphStyle()
        spaced.lineHeightMultiple = Theme.Size.translationLineHeight
        spaced.paragraphSpacing = fontSize
        var translation = body
        translation[.paragraphStyle] = spaced
        let output = NSMutableAttributedString()
        for paragraph in paragraphs where !paragraph.text.isEmpty {
            if output.length > 0 { output.append(NSAttributedString(string: "\n", attributes: translation)) }
            if !paragraph.source.isEmpty {
                output.append(NSAttributedString(string: paragraph.source + "\n", attributes: source))
            }
            output.append(NSAttributedString(string: paragraph.text, attributes: translation))
        }
        return output
    }
}
