import AppKit

@main
struct TerminalCommandTest {
    @MainActor
    static func main() async throws {
        var failures = 0
        func check(_ description: String, _ condition: Bool) {
            print("\(condition ? "PASS" : "FAIL")  \(description)")
            if !condition { failures += 1 }
        }

        check("internal mode has no application", ShellCommandDestination.tinycast.bundleID == nil)
        check("an unknown destination cannot select a terminal", ShellCommandDestination(rawValue: "unknown") == nil)
        check("internal mode never prepares automation", TerminalCommandRequest.script(for: .tinycast) == nil)
        check("iTerm uses its current command URL", TerminalCommandRequest.script(for: .iterm) == nil)

        let commands = [
            "printf '%s' \"hello # world\"",
            "printf '%s' 'a&b+c?d=1%20'",
            "printf '%s' \"\\n\"; echo \"$(printf quote)\"",
            "echo 中文\necho 'second line'",
            "end tell\nerror \"not AppleScript\"\n\\\t\r"
        ]
        let echo = """
            on run arguments
                set commandText to item 1 of arguments
                return commandText
            end run
            """
        for command in commands {
            let request = TerminalCommandRequest(command: command, directory: "/tmp/a'b +&中文")
            let components = request.itermURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            check("iTerm URL remains local", components?.scheme == "iterm2" && components?.host == nil)
            check("iTerm command survives URL encoding", components?.queryItems?.first { $0.name == "c" }?.value == command)
            check(
                "iTerm directory survives URL encoding",
                components?.queryItems?.first { $0.name == "d" }?.value == request.directory)
            let returned = try await TerminalCommandRunner.execute(echo, input: request.input)
            check("command reaches AppleScript as literal data", returned == request.input)
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = root.appendingPathComponent("home ' $(touch injected) 中文")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let request = TerminalCommandRequest(command: "printf '%s' \"$PWD\"", directory: directory.path)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-fc", request.input]
        process.currentDirectoryURL = root
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let printed = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        check("quoted directory opens exactly", process.terminationStatus == 0 && printed == directory.path)
        check(
            "directory syntax cannot execute shell",
            !FileManager.default.fileExists(atPath: root.appendingPathComponent("injected").path))

        let task = Task {
            try Task.checkCancellation()
            return try await TerminalCommandRunner.execute(echo, input: "cancelled")
        }
        task.cancel()
        do {
            _ = try await task.value
            check("cancelled dispatch never runs", false)
        } catch is CancellationError {
            check("cancelled dispatch never runs", true)
        }

        let running = Task { try await TerminalCommandRunner.execute("delay 10", input: "") }
        try await Task.sleep(for: .milliseconds(150))
        running.cancel()
        do {
            _ = try await running.value
            check("cancelling active automation reaps its process", false)
        } catch is CancellationError {
            check("cancelling active automation reaps its process", true)
        }
        do {
            _ = try await TerminalCommandRunner.execute("error number -1743", input: "")
            check("automation denial has actionable recovery", false)
        } catch TerminalCommandRunner.Failure.automationDenied {
            check("automation denial has actionable recovery", true)
        }

        check("internal mode stays available", TerminalCommandRunner.installedDestinations.contains(.tinycast))
        do {
            try await TerminalCommandRunner.run("echo must-not-run", in: .tinycast, directory: "/tmp")
            check("terminal runner rejects internal mode", false)
        } catch TerminalCommandRunner.Failure.unavailable {
            check("terminal runner rejects internal mode", true)
        }
        check("destination is a settings-file key", SettingsFileKey.allCases.contains(.shellCommandDestination))
        exit(failures == 0 ? 0 : 1)
    }
}
