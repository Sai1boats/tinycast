import Foundation

struct PlanoteNoteDraft: Codable, Sendable {
    var noteID: UUID
    var expectedVersion: String
    var title: String
    var markdown: String
    var pendingCommand: PlanoteNoteCommand?
}
