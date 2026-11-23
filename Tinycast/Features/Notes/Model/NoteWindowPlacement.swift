import CoreGraphics

enum NoteWindowPlacement {
    static func resizing(_ frame: CGRect, width: CGFloat, minimum: CGSize, in visible: CGRect) -> CGRect {
        let width = min(visible.width, max(width, minimum.width))
        let height = min(visible.height, max(frame.height, minimum.height))
        return CGRect(x: min(max(frame.maxX - width, visible.minX), visible.maxX - width),
            y: min(max(frame.maxY - height, visible.minY), visible.maxY - height), width: width, height: height)
    }

    static func topRight(_ frame: CGRect, in visibleFrame: CGRect, inset: CGFloat) -> CGRect {
        let horizontalInset = min(inset, max(0, visibleFrame.width - frame.width))
        let verticalInset = min(inset, max(0, visibleFrame.height - frame.height))
        return CGRect(
            x: visibleFrame.maxX - frame.width - horizontalInset,
            y: visibleFrame.maxY - frame.height - verticalInset,
            width: frame.width,
            height: frame.height)
    }
}
