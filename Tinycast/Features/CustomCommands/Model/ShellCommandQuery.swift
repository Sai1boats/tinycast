import Foundation

struct ShellCommandQuery: Equatable, Sendable {
    let command: String

    init?(_ query: String) {
        guard query.hasPrefix("# ") else { return nil }
        command = String(query.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canRun: Bool { !command.isEmpty }
}
