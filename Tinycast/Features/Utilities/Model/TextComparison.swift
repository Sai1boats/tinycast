import Foundation

enum TextComparison {
    enum Failure: Error { case tooLarge, tooManyLines }
    enum Kind: Sendable { case equal, inserted, deleted }
    static let maximumBytes = 131_072
    static let maximumLines = 1_000

    struct Row: Sendable, Equatable {
        let kind: Kind
        let text: String
    }

    struct Result: Sendable {
        let rows: [Row]
        let insertedCount: Int
        let deletedCount: Int
        let output: String
        var isIdentical: Bool { insertedCount == 0 && deletedCount == 0 }

        init(rows: [Row]) {
            self.rows = rows
            insertedCount = rows.filter { $0.kind == .inserted }.count
            deletedCount = rows.filter { $0.kind == .deleted }.count
            output = rows.map { row in
                let prefix = switch row.kind {
                case .equal: "  "
                case .inserted: "+ "
                case .deleted: "- "
                }
                let ending = row.text.hasSuffix("\r\n") ? " [CRLF]"
                    : row.text.hasSuffix("\r") ? " [CR]"
                    : row.text.hasSuffix("\n") ? "" : " [No final newline]"
                let content = row.text.hasSuffix("\n") || row.text.hasSuffix("\r")
                    ? String(row.text.dropLast()) : row.text
                return prefix + content + ending
            }.joined(separator: "\n")
        }
    }

    static func compare(original: String, modified: String) throws -> Result {
        guard original.utf8.count <= maximumBytes, modified.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        let old = try lines(original)
        let new = try lines(modified)
        try Task.checkCancellation()
        let changes = new.difference(from: old)
        try Task.checkCancellation()
        var deleted: Set<Int> = []
        var inserted: Set<Int> = []
        for change in changes {
            switch change {
            case .remove(let offset, _, _): deleted.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        var rows: [Row] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < old.count || newIndex < new.count {
            if deleted.contains(oldIndex), oldIndex < old.count {
                rows.append(Row(kind: .deleted, text: old[oldIndex]))
                oldIndex += 1
            } else if inserted.contains(newIndex), newIndex < new.count {
                rows.append(Row(kind: .inserted, text: new[newIndex]))
                newIndex += 1
            } else {
                rows.append(Row(kind: .equal, text: old[oldIndex]))
                oldIndex += 1
                newIndex += 1
            }
        }
        return Result(rows: rows)
    }

    private static func lines(_ source: String) throws -> [String] {
        var result: [String] = []
        var line = ""
        for character in source {
            line.append(character)
            if character == "\n" || character == "\r\n" || character == "\r" {
                result.append(line)
                line = ""
                guard result.count <= maximumLines else { throw Failure.tooManyLines }
            }
        }
        if !line.isEmpty { result.append(line) }
        guard result.count <= maximumLines else { throw Failure.tooManyLines }
        return result
    }
}
