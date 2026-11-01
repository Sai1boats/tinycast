import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class QRCodeCoordinator {
    let history: QRCodeHistoryStore
    private let palette: PaletteState
    private let report: (String, Bool) -> Void
    private let hidePalette: () -> Void
    private(set) var isBusy = false
    @ObservationIgnored private var operation: Task<Void, Never>?

    init(
        history: QRCodeHistoryStore, palette: PaletteState,
        report: @escaping (String, Bool) -> Void, hidePalette: @escaping () -> Void
    ) {
        self.history = history
        self.palette = palette
        self.report = report
        self.hidePalette = hidePalette
    }

    func load() {
        guard !history.isLoaded else { return }
        perform { try await self.history.load() }
    }

    func generate() {
        guard history.isLoaded else { load(); return }
        let content = palette.query
        let token = palette.resetToken
        perform {
            _ = try await QRCodeRenderer.png(for: content)
            let entries = QRCodeHistory.recording(content, in: self.history.entries, id: UUID(), now: Date())
            try await self.history.replace(entries)
            guard self.palette.mode == .qrCode, self.palette.resetToken == token,
                self.palette.query == content else { return }
            self.palette.selection = 0
            self.palette.followToken = UUID()
        }
    }

    func copy(_ entry: QRCodeEntry) {
        perform {
            let data = try await QRCodeRenderer.png(for: entry.content)
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setData(data, forType: .png) else {
                throw CocoaError(.fileWriteUnknown)
            }
            self.report(String(localized: "Image copied."), false)
        }
    }

    func save(_ entry: QRCodeEntry) {
        perform {
            let data = try await QRCodeRenderer.png(for: entry.content)
            self.hidePalette()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "QRCode.png"
            panel.canCreateDirectories = true
            NSApp.activate()
            guard await panel.begin() == .OK, let url = panel.url else { return }
            try await Self.write(data, to: url)
            self.report(String(localized: "QR code saved."), false)
        }
    }

    func remove(_ entry: QRCodeEntry) {
        perform {
            try await self.history.replace(self.history.entries.filter { $0.id != entry.id })
        }
    }

    func finishPendingWork() async {
        await operation?.value
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        operation = Task { [weak self] in
            defer { self?.isBusy = false; self?.operation = nil }
            do {
                try await action()
            } catch is CancellationError {
            } catch {
                self?.report(error.localizedDescription, true)
            }
        }
    }

    @concurrent private static func write(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }
}
