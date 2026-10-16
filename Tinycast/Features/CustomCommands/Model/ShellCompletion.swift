import Foundation

/// Tab in the ad-hoc shell: command names in command position, file names everywhere else.
enum ShellCompletion {
    struct Candidate: Equatable, Identifiable, Sendable {
        /// The whole line after the prefix once this candidate is chosen.
        let line: String
        let title: String
        let isDirectory: Bool
        var id: String { line }
    }

    struct Entry: Equatable, Sendable {
        let name: String
        let isDirectory: Bool
    }

    /// What Tab is completing: a command name, or a path inside `directory`.
    struct Context: Equatable, Sendable {
        let prefix: String
        let word: String
        let isCommand: Bool
        /// The folder to list for a path, already resolved against the shell's directory.
        let directory: String
        /// The typed folder part of the word, kept verbatim so the line only ever grows.
        let typedFolder: String
        let namePrefix: String
    }

    struct Outcome: Equatable, Sendable {
        /// The line Tab writes now; nil when nothing can be added.
        let line: String?
        /// Shown under the field when more than one name still fits.
        let candidates: [Candidate]
    }

    static let candidateLimit = 200

    static func context(for line: String, directory: String, home: String) -> Context {
        let (prefix, word) = ShellWords.lastWord(of: line)
        let isPath = word.contains("/") || word.hasPrefix("~") || word.hasPrefix(".")
        let isCommand = !isPath && isCommandPosition(prefix)
        let spelled = ShellWords.unescaped(word)
        let slash = word.lastIndex(of: "/")
        let typedFolder = slash.map { String(word[...$0]) } ?? ""
        let namePrefix = slash.map { ShellWords.unescaped(String(word[word.index(after: $0)...])) } ?? spelled
        let folder = ShellWords.unescaped(typedFolder)
        let listed: String
        if folder.isEmpty {
            listed = directory
        } else if folder == "~/" || folder.hasPrefix("~/") {
            listed = home + folder.dropFirst()
        } else if folder.hasPrefix("/") {
            listed = folder
        } else {
            listed = directory + "/" + folder
        }
        return Context(
            prefix: prefix, word: word, isCommand: isCommand,
            directory: URL(fileURLWithPath: listed).standardizedFileURL.path,
            typedFolder: typedFolder, namePrefix: namePrefix)
    }

    static func complete(_ context: Context, commands: [String], entries: [Entry]) -> Outcome {
        let candidates = context.isCommand
            ? commandCandidates(context, names: commands)
            : pathCandidates(context, entries: entries)
        guard let first = candidates.first else { return Outcome(line: nil, candidates: []) }
        if candidates.count == 1 { return Outcome(line: first.line, candidates: []) }
        let shared = candidates.dropFirst().reduce(first.line) { $0.commonPrefix(with: $1.line) }
        let current = context.prefix + context.word
        let grows = shared.count > current.count || shared.count == current.count && shared != current
        return Outcome(line: grows ? shared : nil, candidates: candidates)
    }

    private static func isCommandPosition(_ prefix: String) -> Bool {
        let before = prefix.trimmingCharacters(in: .whitespaces)
        if before.isEmpty { return true }
        if let last = before.last, "|&;(".contains(last) { return true }
        let words = before.split(whereSeparator: \.isWhitespace)
        return words.count == 1 && ["sudo", "time", "nohup", "exec", "which", "man", "type"].contains(words[0])
    }

    private static func commandCandidates(_ context: Context, names: [String]) -> [Candidate] {
        guard !context.namePrefix.isEmpty else { return [] }
        let matches = Set(names.filter { $0.hasPrefix(context.namePrefix) && !$0.hasPrefix("_") }).sorted()
        return matches.prefix(candidateLimit).map {
            Candidate(line: context.prefix + ShellWords.escaped($0) + " ", title: $0, isDirectory: false)
        }
    }

    private static func pathCandidates(_ context: Context, entries: [Entry]) -> [Candidate] {
        let showsHidden = context.namePrefix.hasPrefix(".")
        let lowered = context.namePrefix.lowercased()
        let matches = entries
            .filter { (showsHidden || !$0.name.hasPrefix(".")) && $0.name.lowercased().hasPrefix(lowered) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return matches.prefix(candidateLimit).map { entry in
            let completed = context.typedFolder + ShellWords.escaped(entry.name) + (entry.isDirectory ? "/" : " ")
            return Candidate(
                line: context.prefix + completed, title: entry.name + (entry.isDirectory ? "/" : ""),
                isDirectory: entry.isDirectory)
        }
    }
}
