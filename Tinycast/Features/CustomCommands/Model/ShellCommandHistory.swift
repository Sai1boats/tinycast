import Foundation

struct ShellCommandHistory: Equatable, Sendable {
    static let capacity = 100
    private(set) var commands: [String]
    private(set) var pinnedCommands: [String]

    init(commands: [String] = [], pinnedCommands: [String] = []) {
        let cleaned = Self.cleaned(commands)
        let available = Set(cleaned)
        let pins = Self.cleaned(pinnedCommands).filter(available.contains)
        let pinned = Set(pins)
        self.pinnedCommands = pins
        self.commands = pins + cleaned.filter { !pinned.contains($0) }.prefix(Self.capacity)
    }

    private static func cleaned(_ commands: [String]) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []
        for command in commands {
            let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty, seen.insert(command).inserted else { continue }
            cleaned.append(command)
        }
        return cleaned
    }

    mutating func record(_ command: String) {
        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !pinnedCommands.contains(command) else { return }
        commands.removeAll { $0 == command }
        commands.insert(command, at: pinnedCommands.count)
        commands = Array(commands.prefix(pinnedCommands.count + Self.capacity))
    }

    mutating func remove(_ command: String) {
        commands.removeAll { $0 == command }
        pinnedCommands.removeAll { $0 == command }
    }

    mutating func togglePinned(_ command: String) {
        guard commands.contains(command) else { return }
        commands.removeAll { $0 == command }
        if pinnedCommands.contains(command) {
            pinnedCommands.removeAll { $0 == command }
            commands.insert(command, at: pinnedCommands.count)
        } else {
            pinnedCommands.append(command)
            commands.insert(command, at: pinnedCommands.count - 1)
        }
        commands = Array(commands.prefix(pinnedCommands.count + Self.capacity))
    }

    mutating func moveToTop(_ command: String) {
        guard commands.contains(command) else { return }
        guard pinnedCommands.contains(command) else { return record(command) }
        pinnedCommands.removeAll { $0 == command }
        pinnedCommands.insert(command, at: 0)
        commands.removeAll { $0 == command }
        commands.insert(command, at: 0)
    }

    func rows(for query: ShellCommandQuery) -> [Row] {
        let terms = query.command.split(whereSeparator: \.isWhitespace).map(String.init)
        let pinned = Set(pinnedCommands)
        let matches = commands.filter { command in
            terms.allSatisfy { command.range(of: $0, options: .caseInsensitive) != nil }
        }
        let typed: [Row] = query.canRun && !commands.contains(query.command) ? [.typed(query.command)] : []
        return typed + matches.map { .history($0, isPinned: pinned.contains($0)) }
    }

    enum Row: Equatable, Identifiable, Sendable {
        case typed(String)
        case history(String, isPinned: Bool = false)

        var command: String {
            switch self {
            case .typed(let command), .history(let command, _): command
            }
        }

        var id: String {
            switch self {
            case .typed: "shell-typed"
            case .history(let command, _): "shell-history-" + command
            }
        }

        var isPinned: Bool {
            if case .history(_, let isPinned) = self { return isPinned }
            return false
        }
    }
}
