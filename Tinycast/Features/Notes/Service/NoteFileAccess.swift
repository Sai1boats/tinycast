import Foundation

enum NoteFileAccess {
    static func writeNewFileAtomically(_ data: Data, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    static func coordinatedWrite<Value>(
        at fileURL: URL,
        options: NSFileCoordinator.WritingOptions,
        _ mutation: (URL) throws -> Value
    ) throws -> Value {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<Value, Swift.Error>?
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: options,
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try mutation(coordinatedURL) }
        }
        if let result { return try result.get() }
        if let coordinationError { throw coordinationError }
        throw CocoaError(.fileWriteUnknown)
    }
}
