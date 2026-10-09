import AppKit

final class TerminalBlockLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        guard let textStorage else { return }
        let text = textStorage.string as NSString
        var plainStart = glyphsToShow.location
        for index in glyphsToShow.location..<NSMaxRange(glyphsToShow) {
            let characterIndex = characterIndexForGlyph(at: index)
            guard let portion = Self.portion(of: text.character(at: characterIndex)),
                let container = textContainer(forGlyphAt: index, effectiveRange: nil)
            else { continue }
            if plainStart < index {
                super.drawGlyphs(forGlyphRange: NSRange(location: plainStart, length: index - plainStart), at: origin)
            }
            let glyph = boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)
            let line = lineFragmentRect(forGlyphAt: index, effectiveRange: nil)
            let cell = CGRect(x: glyph.minX + origin.x, y: line.minY + origin.y,
                              width: glyph.width, height: line.height)
            let rectangle = CGRect(x: cell.minX + cell.width * portion.minX,
                                   y: cell.minY + cell.height * portion.minY,
                                   width: cell.width * portion.width, height: cell.height * portion.height)
            let color = textStorage.attribute(.foregroundColor, at: characterIndex, effectiveRange: nil)
                as? NSColor ?? .labelColor
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.shouldAntialias = false
            color.setFill()
            rectangle.fill()
            NSGraphicsContext.restoreGraphicsState()
            plainStart = index + 1
        }
        if plainStart < NSMaxRange(glyphsToShow) {
            super.drawGlyphs(forGlyphRange: NSRange(location: plainStart,
                                                  length: NSMaxRange(glyphsToShow) - plainStart), at: origin)
        }
    }

    private static func portion(of character: unichar) -> CGRect? {
        switch character {
        case 0x2580: CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case 0x2581...0x2588:
            CGRect(x: 0, y: 1 - CGFloat(character - 0x2580) / 8,
                   width: 1, height: CGFloat(character - 0x2580) / 8)
        case 0x2589...0x258F:
            CGRect(x: 0, y: 0, width: CGFloat(0x2590 - character) / 8, height: 1)
        case 0x2590: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        default: nil
        }
    }
}
