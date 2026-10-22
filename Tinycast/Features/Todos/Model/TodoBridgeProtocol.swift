import Foundation

/// Planote ⇄ Tinycast wire types, contract v1. Field names are the contract; v1 is append-only.
enum TodoBridgeProtocol {
    static let schemaVersion = 1

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func isSupported(schemaVersion: Int) -> Bool {
        schemaVersion == self.schemaVersion
    }

    static func validate(_ command: TodoBridgeCommand) throws {
        guard isSupported(schemaVersion: command.schemaVersion) else {
            throw TodoBridgeValidationError.unsupportedSchema(command.schemaVersion)
        }
        switch command.kind {
        case .create, .update:
            guard let task = command.task else { throw TodoBridgeValidationError.missingTask }
            guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TodoBridgeValidationError.emptyTitle
            }
        case .setCompleted:
            guard command.taskID != nil else { throw TodoBridgeValidationError.missingTaskID }
            guard command.isCompleted != nil else {
                throw TodoBridgeValidationError.missingCompletion
            }
        }
    }

    static func validate(_ snapshot: TodoBridgeSnapshot) throws {
        guard isSupported(schemaVersion: snapshot.schemaVersion) else {
            throw TodoBridgeValidationError.unsupportedSchema(snapshot.schemaVersion)
        }
    }
}

enum TodoBridgeValidationError: Error, Equatable {
    case unsupportedSchema(Int)
    case missingTask
    case emptyTitle
    case missingTaskID
    case missingCompletion
}

/// The `errorCode` strings Planote writes into a result; the contract fixes these spellings.
enum TodoBridgeErrorCode {
    static let invalidCommand = "invalidCommand"
    static let invalidTitle = "invalidTitle"
    static let taskNotFound = "taskNotFound"
    static let persistenceFailed = "persistenceFailed"
    static let `internal` = "internal"
}

enum TodoBridgeBucket: String, Codable, Sendable { case later, week, today }

struct TodoBridgeSubtask: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}

struct TodoBridgeLabel: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
}

struct TodoBridgeBoardSection: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    /// Exactly one inbox per snapshot; Planote's inbox id is all zeros.
    var isInbox: Bool
}

struct TodoBridgeTask: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var notes: String
    /// Rich Markdown source; nil for a plain-text or RTF-only note.
    var notesMarkdown: String?
    var startDate: Date?
    var dueDate: Date?
    var bucket: TodoBridgeBucket
    /// nil names the inbox.
    var boardSectionID: UUID?
    var labelID: UUID?
    var isCompleted: Bool
    var subtasks: [TodoBridgeSubtask]
}

struct TodoBridgeSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int
    /// Planote increments it on every changed snapshot it publishes.
    var revision: Int
    var generatedAt: Date
    var tasks: [TodoBridgeTask]
    var labels: [TodoBridgeLabel]
    var boardSections: [TodoBridgeBoardSection]
}

struct TodoBridgeStatus: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var pid: Int32
    var startedAt: Date
    var lastHeartbeatAt: Date
    var revision: Int
}

/// Carries Markdown notes, never plain ones: Planote derives those from it.
struct TodoBridgeTaskPayload: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var startDate: Date?
    var dueDate: Date?
    var boardSectionID: UUID?
    var labelID: UUID?
    var subtasks: [TodoBridgeSubtask]
    /// Markdown source for the task's notes; nil leaves the stored notes untouched.
    var notesMarkdown: String?

    /// Explicit, so notes stay an optional trailing argument without a lint-flagged nil default.
    init(
        id: UUID, title: String, startDate: Date? = nil, dueDate: Date? = nil,
        boardSectionID: UUID? = nil, labelID: UUID? = nil,
        subtasks: [TodoBridgeSubtask], notesMarkdown: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.dueDate = dueDate
        self.boardSectionID = boardSectionID
        self.labelID = labelID
        self.subtasks = subtasks
        self.notesMarkdown = notesMarkdown
    }
}

enum TodoBridgeCommandKind: String, Codable, Sendable { case create, update, setCompleted }

struct TodoBridgeCommand: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var requestID: UUID
    var kind: TodoBridgeCommandKind
    var sentAt: Date
    /// Carried by create and update.
    var task: TodoBridgeTaskPayload?
    /// Carried by setCompleted.
    var taskID: UUID?
    var isCompleted: Bool?
}

struct TodoBridgeResult: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var requestID: UUID
    var ok: Bool
    var completedAt: Date
    /// The revision the snapshot carries after applying, or the last known one on error.
    var revision: Int
    var errorCode: String?
    var errorMessage: String?
}
