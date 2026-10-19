import Foundation

/// Where the Planote todo bridge lives, derived from an injected home directory.
struct TodoBridgePaths: Sendable {
    let baseURL: URL
    let snapshotURL: URL
    let statusURL: URL
    let commandsDirectory: URL
    let resultsDirectory: URL

    init(homeDirectory: URL) {
        baseURL = homeDirectory.appending(
            path: "Library/Application Support/Planote/TodoBridge", directoryHint: .isDirectory)
        snapshotURL = baseURL.appending(path: "snapshot.json", directoryHint: .notDirectory)
        statusURL = baseURL.appending(path: "status.json", directoryHint: .notDirectory)
        commandsDirectory = baseURL.appending(path: "commands", directoryHint: .isDirectory)
        resultsDirectory = baseURL.appending(path: "results", directoryHint: .isDirectory)
    }

    /// Planote processes commands in ascending filename order, so millis lead and stay zero-padded.
    func commandFilename(for requestID: UUID, at date: Date) -> String {
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        return String(format: "%013lld-%@.json", millis, requestID.uuidString)
    }
}
