import Foundation

struct ShellCommandQuery: Equatable, Sendable {
    let command: String
    /// Exactly as typed after the prefix, trailing space included; completion reads the cursor's word.
    let input: String

    init?(_ query: String) {
        guard query.hasPrefix("# ") else { return nil }
        input = String(query.dropFirst(2))
        command = input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canRun: Bool { !command.isEmpty }
}
