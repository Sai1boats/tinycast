import AppKit
import Foundation
import Vision

@main @MainActor
struct QRCodeTests {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await renderRoundTrips()
        try await persistence(directory)
        try await coordinatorOrdering(directory)
        print("QR code decoding, capacity, persistence, failure recovery and operation ordering passed")
    }

    static func renderRoundTrips() async throws {
        for text in ["https://tinycast.app", "二维码测试 👋 café", "  exact text  ", String(repeating: "a", count: 2_000)] {
            let data = try await QRCodeRenderer.png(for: text)
            var request = DetectBarcodesRequest()
            request.symbologies = [.qr]
            let results = try await request.perform(on: data)
            precondition(results.first?.payloadString == text, "Generated PNG must decode to the exact UTF-8 input")
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            precondition(image.width == image.height && image.width.isMultiple(of: 8))
        }
        for invalid in ["", " \n ", String(repeating: "a", count: 2_001), String(repeating: "中", count: 667)] {
            do {
                _ = try await QRCodeRenderer.png(for: invalid)
                preconditionFailure("Invalid payload accepted")
            } catch is QRCodeHistory.Failure {}
        }
    }

    static func persistence(_ directory: URL) async throws {
        let url = directory.appendingPathComponent("history.json")
        let store = QRCodeHistoryStore(fileURL: url)
        try await store.load()
        precondition(store.entries.isEmpty)
        var entries: [QRCodeEntry] = []
        for index in 0..<205 {
            entries = QRCodeHistory.recording(
                "\(index)", in: entries, id: UUID(), now: Date(timeIntervalSince1970: Double(index)))
        }
        precondition(entries.count == 200 && entries.last?.content == "5")
        entries = QRCodeHistory.recording("100", in: entries, id: UUID(), now: Date(timeIntervalSince1970: 300))
        precondition(entries.count == 200 && entries.first?.content == "100")
        precondition(entries.filter { $0.content == "100" }.count == 1)
        try await store.replace(entries)
        let reopened = QRCodeHistoryStore(fileURL: url)
        try await reopened.load()
        precondition(reopened.entries == entries)
        try await reopened.replace(Array(entries.dropFirst()))
        let deleted = QRCodeHistoryStore(fileURL: url)
        try await deleted.load()
        precondition(deleted.entries.count == 199 && deleted.entries.first?.content == "204")
        let malformed = Data("broken json".utf8)
        try malformed.write(to: url)
        let broken = QRCodeHistoryStore(fileURL: url)
        do {
            try await broken.load()
            preconditionFailure("Malformed history must report an error")
        } catch is QRCodeHistory.Failure {}
        do {
            try await broken.replace([])
            preconditionFailure("Unreadable history must not be overwritten")
        } catch is QRCodeHistory.Failure {}
        let unchanged = try Data(contentsOf: url)
        precondition(unchanged == malformed)
        let blockedURL = url.appendingPathComponent("not-a-directory.json")
        let blocked = QRCodeHistoryStore(fileURL: blockedURL)
        try await blocked.load()
        do {
            try await blocked.replace(entries)
            preconditionFailure("Write failure must surface")
        } catch {}
        precondition(blocked.entries.isEmpty)
    }

    static func coordinatorOrdering(_ directory: URL) async throws {
        let palette = PaletteState()
        let store = QRCodeHistoryStore(fileURL: directory.appendingPathComponent("coordinator.json"))
        var reports: [String] = []
        let coordinator = QRCodeCoordinator(
            history: store, palette: palette, report: { message, _ in reports.append(message) }, hidePalette: {})
        coordinator.load()
        await coordinator.finishPendingWork()
        palette.query = "first"
        coordinator.generate()
        coordinator.generate()
        await coordinator.finishPendingWork()
        precondition(store.entries.count == 1 && !coordinator.isBusy)
        palette.query = "second"
        coordinator.generate()
        palette.mode = .launcher
        palette.selection = 12
        await coordinator.finishPendingWork()
        precondition(store.entries.first?.content == "second" && palette.selection == 12)
        palette.mode = .qrCode
        palette.query = "third"
        coordinator.generate()
        palette.resetToken = UUID()
        palette.selection = 7
        await coordinator.finishPendingWork()
        precondition(palette.selection == 7)
        palette.query = ""
        coordinator.generate()
        await coordinator.finishPendingWork()
        precondition(reports.count == 1 && store.entries.count == 3)
        coordinator.remove(store.entries[0])
        await coordinator.finishPendingWork()
        precondition(store.entries.count == 2)
    }
}

@MainActor final class PaletteState {
    enum Mode { case qrCode, launcher }
    var mode: Mode = .qrCode
    var query = ""
    var resetToken = UUID()
    var followToken = UUID()
    var selection = 0
}
