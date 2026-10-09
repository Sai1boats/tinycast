import AppKit

@main
struct TerminalBlockTests {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        for scale in [1, 2] {
            try verify(scale: scale)
        }
        print("Terminal blocks join across rows and columns at 1× and 2×; source text is preserved")
    }

    @MainActor
    static func verify(scale: Int) throws {
        let source = "████\n████\n▀▄█ Text 中文"
        let storage = NSTextStorage(string: source, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.black
        ])
        let layout = TerminalBlockLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 400, height: 200))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        let width = 400 * scale
        let height = 200 * scale
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.coderInvalidValue) }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        layout.drawGlyphs(forGlyphRange: layout.glyphRange(for: container), at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        let first = layout.boundingRect(forGlyphRange: NSRange(location: 0, length: 4), in: container)
        let second = layout.lineFragmentRect(forGlyphAt: 5, effectiveRange: nil)
        guard let data = context.data else { throw CocoaError(.coderInvalidValue) }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        for row in 1..<Int(second.maxY * CGFloat(scale)) - 1 {
            for column in 1..<Int(first.maxX * CGFloat(scale)) - 1 {
                let offset = (row * width + column) * 4
                precondition(pixels[offset] == 0, "Gap at \(column), \(row), scale \(scale)")
            }
        }
        for (index, upper, lower) in [(10, UInt8(0), UInt8(255)), (11, UInt8(255), UInt8(0))] {
            let glyph = layout.boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)
            let line = layout.lineFragmentRect(forGlyphAt: index, effectiveRange: nil)
            let column = Int(glyph.midX * CGFloat(scale))
            for (fraction, expected) in [(0.25, upper), (0.75, lower)] {
                let row = Int((line.minY + line.height * fraction) * CGFloat(scale))
                precondition(pixels[(row * width + column) * 4] == expected)
            }
        }
        precondition(storage.string == source)
        let view = NSTextView(frame: .zero, textContainer: container)
        view.setSelectedRange(NSRange(location: 0, length: storage.length))
        let selected = (view.string as NSString).substring(with: view.selectedRange())
        precondition(selected == source)
    }
}
