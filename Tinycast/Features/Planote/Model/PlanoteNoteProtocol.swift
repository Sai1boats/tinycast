import Foundation

struct PlanoteNoteSummary: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var version: String
    var modifiedAt: Date
    var attachmentCount: Int
}

struct PlanoteNote: Codable, Equatable, Sendable {
    var summary: PlanoteNoteSummary
    var markdown: String
}

struct PlanoteNoteSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var notes: [PlanoteNoteSummary]
}

struct PlanoteNoteCommand: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var requestID: UUID
    var noteID: UUID
    var expectedVersion: String
    var title: String
    var markdown: String
}

struct PlanoteNoteResult: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var requestID: UUID
    var note: PlanoteNote?
    var errorCode: String?
    var errorMessage: String?
}

enum PlanoteNoteProtocol {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
