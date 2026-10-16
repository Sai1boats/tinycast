import AppKit

@MainActor
enum TerminalCommandRunner {
    enum Failure: LocalizedError, Sendable {
        case unavailable(String)
        case automationDenied
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let name):
                String(localized: "\(name) is not installed. Choose another terminal in Settings → Commands.")
            case .automationDenied:
                String(
                    localized: "Allow Tinycast to control this terminal in System Settings → Privacy & Security → Automation.")
            case .executionFailed(let detail):
                String(localized: "The terminal command could not be sent.\n\n\(detail)")
            }
        }
    }

    static var installedDestinations: [ShellCommandDestination] {
        ShellCommandDestination.allCases.filter { destination in
            guard let bundleID = destination.bundleID else { return true }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
    }

    static func run(_ command: String, in destination: ShellCommandDestination, directory: String) async throws {
        try Task.checkCancellation()
        guard let bundleID = destination.bundleID,
            let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { throw Failure.unavailable(destination.name) }
        let request = TerminalCommandRequest(command: command, directory: directory)
        if destination == .iterm {
            guard let url = request.itermURL else {
                throw Failure.executionFailed(String(localized: "The command URL could not be prepared."))
            }
            _ = try await NSWorkspace.shared.open(
                [url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        guard let source = TerminalCommandRequest.script(for: destination) else { return }
        _ = try await execute(source, input: request.input)
    }

    @concurrent
    static func execute(_ source: String, input: String) async throws -> String? {
        try Task.checkCancellation()
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source, "--", input]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let exit = try process.runObservingExit()
            defer {
                if process.isRunning { process.terminate() }
                exit.wait()
                try? output.fileHandleForReading.close()
            }
            if Task.isCancelled, process.isRunning { process.terminate() }
            var captured = Data()
            while let chunk = try output.fileHandleForReading.read(upToCount: outputLimit), !chunk.isEmpty {
                captured.append(chunk)
                if captured.count > outputLimit { captured = captured.suffix(outputLimit) }
            }
            exit.wait()
            try Task.checkCancellation()
            let text = String(data: captured, encoding: .utf8) ?? String(localized: "Unknown automation error.")
            guard process.terminationStatus == 0 else {
                if text.contains("(-1743)") { throw Failure.automationDenied }
                throw Failure.executionFailed(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if captured.last == 0x0a { captured.removeLast() }
            return String(data: captured, encoding: .utf8)
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    nonisolated private static let outputLimit = 8 * 1024
}
