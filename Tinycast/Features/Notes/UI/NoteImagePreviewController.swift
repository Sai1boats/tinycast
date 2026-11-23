import SwiftUI

@MainActor
final class NoteImagePreviewController {
    private var panel: NotesPanel?

    func show(_ url: URL, in host: NSWindow) {
        hide()
        let size = host.frame.size
        let view = NoteImagePreview(url: url, close: { [weak self] in self?.hide() })
        let panel = NotesPanel(
            content: NSHostingView(rootView: view), size: size,
            styleMask: [.borderless, .resizable], acceptsMain: false)
        panel.closesWithSpace = true
        panel.onEscape = { [weak self] in self?.hide() }
        panel.commandChords = [
            "w": { [weak self] in self?.hide() },
            "o": { AppLauncher.showInFinder(url) },
            "c": {
                guard let image = NSImage(contentsOf: url) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
        ]
        panel.setFrame(host.frame, display: false)
        host.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func hide() {
        guard let panel else { return }
        let host = panel.parent
        host?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
        host?.makeKey()
    }
}

private struct NoteImagePreview: View {
    let url: URL
    let close: () -> Void
    @State private var original = false
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text(url.lastPathComponent).lineLimit(1)
                Spacer()
                Button {
                    original.toggle()
                } label: {
                    Image(systemName: original ? "minus.magnifyingglass" : "plus.magnifyingglass")
                }.accessibilityLabel("Zoom")
                Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("Close")
            }
            if let image {
                if original {
                    ScrollView([.horizontal, .vertical]) { Image(nsImage: image) }
                } else {
                    Image(nsImage: image).resizable().scaledToFit().frame(
                        maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Text("Image unavailable").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Theme.Size.noteEditorInset)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
        .task(id: url) {
            if let data = try? await Self.load(url), !Task.isCancelled { image = NSImage(data: data) }
        }
    }

    @concurrent
    private static func load(_ url: URL) async throws -> Data { try Data(contentsOf: url) }
}
