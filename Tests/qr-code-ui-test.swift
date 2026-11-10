import AppKit
import Observation
import SwiftUI
import Vision

@main @MainActor
struct QRCodeUITests {
    static func main() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QRCodeHistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        try await store.load()
        let entries = ["https://tinycast.app", "二维码历史记录", "https://example.com/docs"].map {
            QRCodeEntry(id: UUID(), content: $0, createdAt: Date())
        }
        try await store.replace(entries)
        let palette = PaletteState()
        let coordinator = QRCodeCoordinator(history: store, palette: palette, report: { _, _ in }, hidePalette: {})
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            for scale in [1.0, 1.1, 1.2] {
                let metrics = InterfaceMetrics(scale: scale)
                let view = QRCodeView(entries: entries, selected: entries[0], scroll: ScrollIntent(kind: .top),
                                      onSelect: { _ in }, onActions: { _ in })
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Text("https://tinycast.app").font(metrics.typography.searchField)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, metrics.spacing.xxl)
                            .frame(height: metrics.size.headerHeight + metrics.size.headerPadding)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Text("Generate QR Code   ↵").font(metrics.typography.bar)
                            .frame(height: metrics.size.bottomBarHeight)
                    }
                    .environment(coordinator).environment(palette).environment(\.metrics, metrics)
                    .background(Theme.Colors.utilitySurface)
                let root = NSHostingView(rootView: view)
                let size = NSSize(width: metrics.size.panelWidth, height: metrics.size.panelHeight)
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: appearance)
                window.contentView = root
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(500))
                root.layoutSubtreeIfNeeded()
                let data = try snapshot(root)
                var request = DetectBarcodesRequest()
                request.symbologies = [.qr]
                let codes = try await request.perform(on: data)
                precondition(codes.contains { $0.payloadString == entries[0].content },
                             "The native preview must remain scannable: \(name), \(scale)")
                if let path = ProcessInfo.processInfo.environment["TINYCAST_QR_PREVIEW_DIRECTORY"] {
                    let output = URL(fileURLWithPath: path)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    try data.write(to: output.appendingPathComponent("qr-\(name)-\(scale).png"))
                }
                window.close()
            }
        }
        print("Native QR split view is scannable in Dark and Light at all three interface sizes")
    }

    static func snapshot(_ root: NSView) throws -> Data {
        guard let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
            throw CocoaError(.fileReadUnknown)
        }
        root.cacheDisplay(in: root.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}

@MainActor @Observable final class PaletteState {
    enum Mode { case qrCode, launcher }
    var mode: Mode = .qrCode
    var query = ""
    var resetToken = UUID()
    var followToken = UUID()
    var selection = 0
    var hoverHighlightArmed = false
    var hoverDisarmToken = UUID()
}

enum SystemSymbolName {
    static func resolve(_ name: String, isDark: Bool) -> String { name }
}
