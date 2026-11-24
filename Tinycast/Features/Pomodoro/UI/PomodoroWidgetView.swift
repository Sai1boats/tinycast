import AppKit
import SwiftUI

/// The widget's two faces on one glass card; the controller resizes the panel to match.
struct PomodoroWidgetView: View {
    @Environment(PomodoroCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if coordinator.isExpanded {
                PomodoroExpandedView()
            } else {
                PomodoroCollapsedView()
            }
        }
        // In front of the hit-testable glass, behind the content, so only the controls win a click.
        .background(
            PomodoroWidgetDragSurface(
                onClick: coordinator.isExpanded ? nil : { coordinator.expandWidget() }))
        .background(Theme.Colors.panelScrim)
        .background(GlassEffectView())
        .clipShape(
            RoundedRectangle(cornerRadius: Theme.Radius.utilityWindow, style: .continuous))
    }
}

/// Drags the panel from the card's background; a press that never moved expands the collapsed face.
private struct PomodoroWidgetDragSurface: NSViewRepresentable {
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> PomodoroWidgetDragView { PomodoroWidgetDragView() }

    func updateNSView(_ view: PomodoroWidgetDragView, context: Context) {
        view.onClick = onClick
    }
}

private final class PomodoroWidgetDragView: NSView {
    var onClick: (() -> Void)?
    /// Slop before a press counts as a drag, so a click that never moves stays a click.
    private static let dragSlop: CGFloat = 3

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        // Deltas off `mouseLocation`, so no view or window coordinate conversion can drift.
        let origin = window.frame.origin
        let start = NSEvent.mouseLocation
        var dragging = false
        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration,
            mode: .eventTracking
        ) { tracked, stop in
            guard let tracked, tracked.type != .leftMouseUp else {
                stop.pointee = true
                return
            }
            let mouse = NSEvent.mouseLocation
            guard dragging || hypot(mouse.x - start.x, mouse.y - start.y) > Self.dragSlop else {
                return
            }
            dragging = true
            window.setFrameOrigin(
                CGPoint(x: origin.x + mouse.x - start.x, y: origin.y + mouse.y - start.y))
        }
        if !dragging { onClick?() }
    }
}
