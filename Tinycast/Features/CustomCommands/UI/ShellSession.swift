import AppKit
import Observation

/// The ad-hoc shell's terminal state: where it stands and what Tab is offering. Never persisted.
@MainActor
@Observable
final class ShellSession {
    struct Completions: Equatable {
        /// The palette query these were computed for; any other query hides them.
        let query: String
        let candidates: [ShellCompletion.Candidate]
    }

    private(set) var directory: String
    private(set) var previousDirectory: String?
    private(set) var completions: Completions?
    private let home: String
    @ObservationIgnored private var commandNames: [String]?
    @ObservationIgnored private var loadingNames: Task<[String], Never>?
    @ObservationIgnored private var completing: Task<Void, Never>?

    init(home: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.home = home
        directory = home
    }

    var displayDirectory: String { ShellPath.abbreviated(directory, home: home) }

    func candidates(for query: String) -> [ShellCompletion.Candidate] {
        completions?.query == query ? completions?.candidates ?? [] : []
    }

    /// Nil on success; otherwise the reason, which the caller reports.
    func changeDirectory(to argument: String?) -> String? {
        guard let path = ShellPath.resolve(argument, from: directory, previous: previousDirectory, home: home)
        else { return String(localized: "There is no previous directory.") }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return String(localized: "“\(ShellPath.abbreviated(path, home: home))” is not a folder.")
        }
        if path != directory {
            previousDirectory = directory
            directory = path
        }
        return nil
    }

    func complete(_ query: ShellCommandQuery, in palette: PaletteState) {
        completing?.cancel()
        let typed = "# " + query.input
        let context = ShellCompletion.context(for: query.input, directory: directory, home: home)
        completing = Task { [weak self] in
            guard let self else { return }
            let names = context.isCommand ? await self.names() : []
            let entries = context.isCommand ? [] : await ShellCompletionSource.entries(in: context.directory)
            guard !Task.isCancelled, palette.query == typed else { return }
            let outcome = ShellCompletion.complete(context, commands: names, entries: entries)
            if let line = outcome.line { palette.rewriteQuery("# " + line) }
            if outcome.line == nil, outcome.candidates.isEmpty { NSSound.beep() }
            completions = outcome.candidates.count > 1
                ? Completions(query: palette.query, candidates: outcome.candidates) : nil
            palette.selection = 0
            palette.followToken = UUID()
        }
    }

    func clearCompletions() {
        completing?.cancel()
        completions = nil
    }

    /// Spawned once per launch on the first Tab; an empty answer is retried on the next one.
    private func names() async -> [String] {
        if let commandNames { return commandNames }
        let task = loadingNames ?? Task { await ShellCompletionSource.commandNames() }
        loadingNames = task
        let names = await task.value
        loadingNames = nil
        if !names.isEmpty { commandNames = names }
        return names
    }
}
