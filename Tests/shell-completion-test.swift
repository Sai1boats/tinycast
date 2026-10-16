import Foundation

@main
@MainActor
struct ShellCompletionTests {
    static var failures = 0

    static func main() async throws {
        testQuery()
        testBuiltins()
        testWords()
        testPaths()
        testCommandCompletion()
        testPathCompletion()
        try await testListing()
        if failures > 0 { exit(1) }
        print("Shell built-ins, quoting, paths, command and file completion passed")
    }

    static func testQuery() {
        let query = ShellCommandQuery("# git ")!
        check(query.input == "git " && query.command == "git", "the raw input keeps the trailing space")
        check(ShellCommandQuery("#git") == nil, "the prefix needs its space")
    }

    static func testBuiltins() {
        check(ShellBuiltin("cd") == .changeDirectory(nil), "bare cd goes home")
        check(ShellBuiltin("  cd   ~/src  ") == .changeDirectory("~/src"), "cd trims its argument")
        check(ShellBuiltin(#"cd "My Files""#) == .changeDirectory("My Files"), "double quotes group a word")
        check(ShellBuiltin(#"cd My\ Files"#) == .changeDirectory("My Files"), "escaped spaces group a word")
        check(ShellBuiltin("cd -") == .changeDirectory("-"), "cd - is kept for the previous folder")
        check(ShellBuiltin("cdf") == .changeToFinderFolder, "cdf follows Finder")
        for line in ["cd src && make", "cd $HOME", "cd a b", "cd `pwd`", "cdx", "echo cd", #"cd "open"#] {
            check(ShellBuiltin(line) == nil, "\(line) runs as real shell")
        }
    }

    static func testWords() {
        check(ShellWords.lastWord(of: "ls ").word == "" && ShellWords.lastWord(of: "ls ").prefix == "ls ",
              "a trailing space starts a new word")
        check(ShellWords.lastWord(of: #"open My\ Fi"#) == ("open ", #"My\ Fi"#), "escaped spaces stay in the word")
        check(ShellWords.lastWord(of: "git") == ("", "git"), "the first word has no prefix")
        check(ShellWords.escaped("a b&c's.txt") == #"a\ b\&c\'s.txt"#, "names are escaped for the shell")
        check(ShellWords.unescaped(#"a\ b\\c"#) == #"a b\c"#, "escapes are read back")
    }

    static func testPaths() {
        let home = "/Users/test"
        check(ShellPath.resolve(nil, from: "/tmp", previous: nil, home: home) == home, "nil is home")
        check(ShellPath.resolve("~", from: "/tmp", previous: nil, home: home) == home, "~ is home")
        check(ShellPath.resolve("~/src", from: "/tmp", previous: nil, home: home) == home + "/src", "~/ expands")
        check(ShellPath.resolve("..", from: "/tmp/a/b", previous: nil, home: home) == "/tmp/a", ".. climbs")
        check(ShellPath.resolve("c/./d", from: "/tmp", previous: nil, home: home) == "/tmp/c/d", "relative joins")
        check(ShellPath.resolve("/etc", from: "/tmp", previous: nil, home: home) == "/etc", "absolute stays")
        check(ShellPath.resolve("-", from: "/tmp", previous: "/var", home: home) == "/var", "- is the previous")
        check(ShellPath.resolve("-", from: "/tmp", previous: nil, home: home) == nil, "- needs a previous")
        check(ShellPath.abbreviated(home + "/src", home: home) == "~/src", "home abbreviates")
        check(ShellPath.abbreviated(home, home: home) == "~", "home itself is ~")
        check(ShellPath.abbreviated("/Users/tester", home: home) == "/Users/tester", "a sibling is not home")
    }

    static func testCommandCompletion() {
        let names = ["git", "gitk", "git-lfs", "gzip", "_git", "git", "ls"]
        let context = ShellCompletion.context(for: "gi", directory: "/tmp", home: "/Users/test")
        check(context.isCommand, "the first word completes commands")
        let outcome = ShellCompletion.complete(context, commands: names, entries: [])
        check(outcome.line == "git", "shared prefix extends the line")
        check(outcome.candidates.map(\.title) == ["git", "git-lfs", "gitk"], "duplicates and _helpers are hidden")
        let single = ShellCompletion.complete(
            ShellCompletion.context(for: "gz", directory: "/tmp", home: "/"), commands: names, entries: [])
        check(single.line == "gzip " && single.candidates.isEmpty, "one match completes with a space")
        let piped = ShellCompletion.context(for: "cat x | gr", directory: "/tmp", home: "/")
        check(piped.isCommand, "after a pipe is command position")
        check(ShellCompletion.context(for: "sudo ls", directory: "/tmp", home: "/").isCommand, "after sudo too")
        check(!ShellCompletion.context(for: "git sta", directory: "/tmp", home: "/").isCommand,
              "an argument completes files")
        let none = ShellCompletion.complete(
            ShellCompletion.context(for: "zzz", directory: "/tmp", home: "/"), commands: names, entries: [])
        check(none.line == nil && none.candidates.isEmpty, "no match changes nothing")
    }

    static func testPathCompletion() {
        let entries = [
            ShellCompletion.Entry(name: "Documents", isDirectory: true),
            ShellCompletion.Entry(name: "Downloads", isDirectory: true),
            ShellCompletion.Entry(name: "My File.txt", isDirectory: false),
            ShellCompletion.Entry(name: ".zshrc", isDirectory: false)
        ]
        let context = ShellCompletion.context(for: "cd ~/do", directory: "/tmp", home: "/Users/test")
        check(context.directory == "/Users/test" && context.namePrefix == "do" && context.typedFolder == "~/",
              "a ~/ word lists home")
        let outcome = ShellCompletion.complete(context, commands: [], entries: entries)
        check(outcome.candidates.map(\.title) == ["Documents/", "Downloads/"], "matching ignores case")
        check(outcome.line == "cd ~/Do", "the shared prefix takes the file system's case")
        let file = ShellCompletion.complete(
            ShellCompletion.context(for: "open my", directory: "/tmp", home: "/"), commands: [], entries: entries)
        check(file.line == #"open My\ File.txt "#, "a file name is escaped and ends the word")
        let hidden = ShellCompletion.complete(
            ShellCompletion.context(for: "vim .z", directory: "/tmp", home: "/"), commands: [], entries: entries)
        check(hidden.line == "vim .zshrc ", "a dot prefix reaches hidden files")
        let all = ShellCompletion.complete(
            ShellCompletion.context(for: "ls ", directory: "/tmp", home: "/"), commands: [], entries: entries)
        check(all.candidates.count == 3 && all.line == nil, "an empty word lists visible entries")
        let nested = ShellCompletion.context(for: #"ls a\ b/c"#, directory: "/tmp", home: "/")
        check(nested.directory == "/tmp/a b" && nested.namePrefix == "c", "escaped folders resolve")
        let dir = ShellCompletion.complete(
            ShellCompletion.context(for: "cd Doc", directory: "/tmp", home: "/"), commands: [], entries: entries)
        check(dir.line == "cd Documents/", "a folder completes with a slash, ready for more")
    }

    static func testListing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shell-completion-\(UUID())")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("folder"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("file.txt"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("link"), withDestinationURL: root.appendingPathComponent("folder"))
        let entries = await ShellCompletionSource.entries(in: root.path)
            .sorted { $0.name < $1.name }
        check(entries == [
            ShellCompletion.Entry(name: "file.txt", isDirectory: false),
            ShellCompletion.Entry(name: "folder", isDirectory: true),
            ShellCompletion.Entry(name: "link", isDirectory: true)
        ], "listing marks folders, following links")
        check(await ShellCompletionSource.entries(in: root.path + "/missing").isEmpty, "a missing folder lists nothing")
    }

    static func check(_ condition: Bool, _ message: String) {
        guard !condition else { return }
        failures += 1
        print("FAIL: \(message)")
    }
}
