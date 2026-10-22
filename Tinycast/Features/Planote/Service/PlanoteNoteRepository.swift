import Foundation

struct PlanoteNoteRepository: Sendable {
    let directory: URL
    let drafts: URL

    @concurrent func list() async throws -> [PlanoteNoteSummary] {
        let url = directory.appending(path: "snapshot.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let snapshot = try PlanoteNoteProtocol.decoder().decode(
            PlanoteNoteSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return snapshot.notes
    }

    @concurrent func load(_ id: UUID) async throws -> PlanoteNote {
        try PlanoteNoteProtocol.decoder().decode(
            PlanoteNote.self, from: Data(contentsOf: directory.appending(path: "notes/\(id.uuidString).json")))
    }

    @concurrent func loadDraft(_ id: UUID) async throws -> PlanoteNoteDraft? {
        let url = drafts.appending(path: "\(id.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try PlanoteNoteProtocol.decoder().decode(PlanoteNoteDraft.self, from: Data(contentsOf: url))
    }

    @concurrent func preserve(_ command: PlanoteNoteDraft) async throws {
        try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
        try PlanoteNoteProtocol.encoder().encode(command)
            .write(to: drafts.appending(path: "\(command.noteID.uuidString).json"), options: .atomic)
    }

    @concurrent func archiveDraft(title: String, markdown: String) async throws {
        try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
        let url = drafts.appending(path: "Recovered-\(UUID().uuidString).md")
        try ("# " + title + "\n\n" + markdown).write(to: url, atomically: true, encoding: .utf8)
    }

    @concurrent func removeDraft(_ id: UUID) async throws {
        let url = drafts.appending(path: "\(id.uuidString).json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    @concurrent func send(_ command: PlanoteNoteCommand) async throws -> PlanoteNoteResult {
        try Task.checkCancellation()
        let folder = directory.appending(path: "commands")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let resultURL = directory.appending(path: "results/\(command.requestID.uuidString).json")
        let file = folder.appending(path: "\(command.requestID.uuidString).json")
        if !FileManager.default.fileExists(atPath: resultURL.path) {
            try PlanoteNoteProtocol.encoder().encode(command).write(to: file, options: .atomic)
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(12))
        while clock.now < deadline {
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: resultURL.path) {
                let result = try PlanoteNoteProtocol.decoder().decode(
                    PlanoteNoteResult.self, from: Data(contentsOf: resultURL))
                guard result.schemaVersion == 1, result.requestID == command.requestID else {
                    throw CocoaError(.coderReadCorrupt)
                }
                return result
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CocoaError(.fileReadUnknown, userInfo: [
            NSLocalizedDescriptionKey: String(localized: "Planote did not answer in time. The draft is kept.")
        ])
    }
}
