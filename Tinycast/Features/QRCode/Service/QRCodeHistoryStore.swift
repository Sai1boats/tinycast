import Foundation
import Observation

@MainActor @Observable
final class QRCodeHistoryStore {
    private(set) var entries: [QRCodeEntry] = []
    private(set) var isLoaded = false
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws {
        guard !isLoaded else { return }
        entries = try await Self.read(fileURL)
        isLoaded = true
    }

    func replace(_ entries: [QRCodeEntry]) async throws {
        guard isLoaded else { throw QRCodeHistory.Failure.invalidHistory }
        try await Self.write(entries, to: fileURL)
        self.entries = entries
    }

    @concurrent private static func read(_ url: URL) async throws -> [QRCodeEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let entries = try? JSONDecoder().decode([QRCodeEntry].self, from: data),
            entries.count <= QRCodeHistory.limit,
            Set(entries.map(\.id)).count == entries.count,
            Set(entries.map(\.content)).count == entries.count,
            entries.allSatisfy({ (try? QRCodeHistory.validate($0.content)) != nil })
        else { throw QRCodeHistory.Failure.invalidHistory }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    @concurrent private static func write(_ entries: [QRCodeEntry], to url: URL) async throws {
        let data = try JSONEncoder().encode(entries)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
