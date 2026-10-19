import Foundation

/// Reads and writes the bridge files; a missing one reads as empty, not a failure.
struct TodoBridgeFileStore {
    private let paths: TodoBridgePaths
    private let fileManager: FileManager

    init(paths: TodoBridgePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func loadSnapshot() throws -> TodoBridgeSnapshot? {
        try load(TodoBridgeSnapshot.self, at: paths.snapshotURL)
    }

    func loadStatus() throws -> TodoBridgeStatus? {
        try load(TodoBridgeStatus.self, at: paths.statusURL)
    }

    /// Liveness is the heartbeat file's age alone; a missing status means Planote is offline.
    func isLive(now: Date, maxAge: TimeInterval) -> Bool {
        guard let modified = modificationDate(of: paths.statusURL) else { return false }
        return now.timeIntervalSince(modified) <= maxAge
    }

    @discardableResult
    func writeCommand(_ command: TodoBridgeCommand) throws -> URL {
        try fileManager.createDirectory(
            at: paths.commandsDirectory, withIntermediateDirectories: true)
        let filename = paths.commandFilename(for: command.requestID, at: command.sentAt)
        let url = paths.commandsDirectory.appending(path: filename, directoryHint: .notDirectory)
        try TodoBridgeProtocol.makeEncoder().encode(command).write(to: url, options: .atomic)
        return url
    }

    func loadResult(requestID: UUID) throws -> TodoBridgeResult? {
        try load(TodoBridgeResult.self, at: resultURL(requestID))
    }

    /// Commands Planote has not consumed yet: the same count the coordinator surfaces.
    func pendingCommandCount() -> Int {
        jsonFilenames(in: paths.commandsDirectory).count
    }

    func removeResult(requestID: UUID) {
        try? fileManager.removeItem(at: resultURL(requestID))
    }

    private func resultURL(_ requestID: UUID) -> URL {
        paths.resultsDirectory.appending(
            path: requestID.uuidString + ".json", directoryHint: .notDirectory)
    }

    private func load<T: Decodable>(_ type: T.Type, at url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try TodoBridgeProtocol.makeDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func modificationDate(of url: URL) -> Date? {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func jsonFilenames(in directory: URL) -> [String] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return names.filter { !$0.hasPrefix(".") && ($0 as NSString).pathExtension == "json" }
    }
}
