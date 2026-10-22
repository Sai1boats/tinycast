import Foundation

@MainActor
final class PlanoteCoordinator {
    var serviceAvailable = false
    func ensureService() async throws {
        if !serviceAvailable { throw CocoaError(.userCancelled) }
    }
    func refresh() {}
}

@main
@MainActor
struct PlanoteTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PlanoteNoteRepository(directory: root, drafts: root.appending(path: "drafts"))
        let empty = try await repository.list()
        precondition(empty.isEmpty)
        let id = UUID()
        let note = PlanoteNote(
            summary: PlanoteNoteSummary(
                id: id, title: "中文项目计划", version: "v1", modifiedAt: .now, attachmentCount: 2),
            markdown: "# 原文\n\n**格式** 📝")
        try FileManager.default.createDirectory(at: root.appending(path: "notes"), withIntermediateDirectories: true)
        try PlanoteNoteProtocol.encoder().encode(note).write(to: root.appending(path: "notes/\(id).json"))
        try PlanoteNoteProtocol.encoder().encode(PlanoteNoteSnapshot(notes: [note.summary]))
            .write(to: root.appending(path: "snapshot.json"))
        let loaded = try await repository.list()
        precondition(loaded.map(\.title) == [note.summary.title])
        let coordinator = PlanoteCoordinator()
        let session = PlanoteNoteSession(note: note, draft: nil, repository: repository, coordinator: coordinator)
        session.markdown = "  # 保留空格\n\n- [x] 完成\n"
        await session.flush()
        precondition(session.isDirty && session.errorMessage != nil)
        let draft = try await repository.loadDraft(id)
        precondition(draft?.markdown == session.markdown)
        let recovered = PlanoteNoteSession(note: note, draft: draft, repository: repository, coordinator: coordinator)
        precondition(recovered.markdown == session.markdown)
        var changed = note
        changed.summary.version = "v2"
        changed.markdown = "另一端修改"
        let conflict = PlanoteNoteSession(note: changed, draft: draft, repository: repository, coordinator: coordinator)
        precondition(conflict.hasConflict && conflict.markdown == draft?.markdown)
        coordinator.serviceAvailable = true
        let responder = Task {
            let commandDirectory = root.appending(path: "commands")
            for _ in 0..<200 {
                let files = (try? FileManager.default.contentsOfDirectory(
                    at: commandDirectory, includingPropertiesForKeys: nil)) ?? []
                for file in files {
                    let command = try PlanoteNoteProtocol.decoder().decode(
                        PlanoteNoteCommand.self, from: Data(contentsOf: file))
                    var saved = note
                    saved.markdown = command.markdown
                    saved.summary.title = command.title
                    saved.summary.version = "v3"
                    let result = PlanoteNoteResult(requestID: command.requestID, note: saved)
                    try FileManager.default.createDirectory(
                        at: root.appending(path: "results"), withIntermediateDirectories: true)
                    try PlanoteNoteProtocol.encoder().encode(result).write(
                        to: root.appending(path: "results/\(command.requestID).json"), options: .atomic)
                    return
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            preconditionFailure("No command arrived")
        }
        await session.flush()
        try await responder.value
        precondition(!session.isDirty && session.errorMessage == nil)
        let cleared = try await repository.loadDraft(id)
        precondition(cleared == nil)
        print("Planote: offline drafts, recovery, conflicts and acknowledged autosave passed")
    }
}
