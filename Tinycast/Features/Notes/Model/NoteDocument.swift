import Foundation

struct NoteID: RawRepresentable, Hashable, Sendable {
    let rawValue: String
}

struct NoteSummary: Identifiable, Sendable, Equatable {
    let id: NoteID
    let title: String
    /// Stands in for `title` while the note is still unnamed; nil once the user names it.
    let firstLine: String?
    let modifiedAt: Date
    var preview: String?
    var tags: [String] = []
    var pendingTaskCount = 0
    var totalTaskCount = 0
    var imageCount = 0
    var contentHash: Data?
    var fileSize: Int?

    var displayTitle: String { firstLine ?? NoteTitle.displayName(title) }
}

struct NoteSearchResult: Identifiable, Sendable, Equatable {
    var id: NoteID { summary.id }
    let summary: NoteSummary
    let score: Int
}

struct NoteDocument: Sendable, Equatable {
    let id: NoteID
    let source: String
}

struct NoteEditorInput: Sendable, Equatable {
    let id: NoteID
    let source: String
    let epoch: Int
}
