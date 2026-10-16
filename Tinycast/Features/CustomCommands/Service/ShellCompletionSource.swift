import Foundation

/// What Tab can offer, read the way the user's own zsh would see it, and never on the main actor.
enum ShellCompletionSource {
    static let timeout = DispatchTimeInterval.seconds(4)
    static let entryLimit = 5000
    private static let outputLimit = 2 * 1024 * 1024

    /// Commands, aliases, functions and builtins from an interactive login zsh, as Tab sees them.
    @concurrent static func commandNames() async -> [String] {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("tinycast-completion-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: output.path, contents: nil),
            let handle = try? FileHandle(forWritingTo: output)
        else { return [] }
        defer { try? FileManager.default.removeItem(at: output) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-ilc", "print -rl -- ${(k)commands} ${(k)aliases} ${(k)functions} ${(k)builtins} ${(k)reswords}"
        ]
        process.environment = ProcessInfo.processInfo.environment.merging(["TINYCAST": "1"]) { _, new in new }
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardInput = FileHandle.nullDevice
        // A file, not a pipe: a daemon the rc file starts can hold a pipe open long after zsh exits.
        process.standardOutput = handle
        process.standardError = FileHandle.nullDevice
        guard let exit = try? process.runObservingExit() else {
            try? handle.close()
            return []
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning { process.terminate() }
        }
        exit.wait()
        try? handle.close()
        guard let data = try? FileHandle(forReadingFrom: output).read(upToCount: outputLimit),
            let text = String(data: data, encoding: .utf8)
        else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let name = String(line)
            return name.isEmpty || name.contains(where: \.isWhitespace) ? nil : name
        }
    }

    @concurrent static func entries(in directory: String) async -> [ShellCompletion.Entry] {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        else { return [] }
        return urls.prefix(entryLimit).map { item in
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            var isDirectory = values?.isDirectory == true
            if values?.isSymbolicLink == true {
                isDirectory = (try? item.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true
            }
            return ShellCompletion.Entry(name: item.lastPathComponent, isDirectory: isDirectory)
        }
    }

    /// Finder's frontmost folder, or the Desktop when no Finder window is open.
    static func finderFolder() async throws -> String? {
        let script = """
            on run arguments
                tell application id "com.apple.finder"
                    if (count of Finder windows) is 0 then return POSIX path of (path to desktop folder)
                    return POSIX path of (target of front Finder window as alias)
                end tell
            end run
            """
        return try await TerminalCommandRunner.execute(script, input: "")
    }
}
