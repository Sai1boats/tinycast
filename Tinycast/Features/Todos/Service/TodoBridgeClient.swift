import AppKit
import Foundation

/// The AppKit half of the bridge: Planote discovery and launch, plus the send-and-wait path.
@MainActor
final class TodoBridgeClient {
    enum Connection: Equatable {
        case checking
        case live(planoteVersion: String?)
        case offline
        case notInstalled
    }

    enum SendError: Error, Equatable {
        case planoteNotInstalled
        case launchTimedOut
        case resultTimedOut
        case commandRejected(code: String?, message: String?)
        case invalidSnapshot
    }

    private static let planoteBundleID = "com.local.MyTodoApp"
    private static let fallbackPlanotePath = "/Applications/Planote.app"
    private static let bridgeOnlyArgument = "--todo-bridge-only"
    private static let livenessMaxAge: TimeInterval = 10

    private let paths: TodoBridgePaths
    private let store: TodoBridgeFileStore

    init(paths: TodoBridgePaths) {
        self.paths = paths
        self.store = TodoBridgeFileStore(paths: paths)
    }

    var planoteAppURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.planoteBundleID)
        {
            return url
        }
        let fallback = URL(fileURLWithPath: Self.fallbackPlanotePath)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    var isPlanoteRunning: Bool {
        NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == Self.planoteBundleID }
    }

    var bridgeDirectoryURL: URL { paths.baseURL }

    func loadSnapshot() -> TodoBridgeSnapshot? {
        guard let loaded = try? store.loadSnapshot() else { return nil }
        return loaded
    }

    func loadStatus() -> TodoBridgeStatus? {
        guard let loaded = try? store.loadStatus() else { return nil }
        return loaded
    }

    func loadResult(for requestID: UUID) -> TodoBridgeResult? {
        guard let loaded = try? store.loadResult(requestID: requestID) else { return nil }
        return loaded
    }

    func isLive(now: Date = .now) -> Bool {
        store.isLive(now: now, maxAge: Self.livenessMaxAge)
    }

    func connection(now: Date = .now) -> Connection {
        guard planoteAppURL != nil else { return .notInstalled }
        guard isLive(now: now) else { return .offline }
        return .live(planoteVersion: planoteVersion)
    }

    /// Bridge-only open: Planote must come up without stealing focus or the frontmost app.
    func launchPlanoteInBackground() async -> Bool {
        guard let appURL = planoteAppURL else { return false }
        if isLive() { return true }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        configuration.arguments = [Self.bridgeOnlyArgument]
        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: appURL, configuration: configuration)
        } catch {
            return false
        }
        let deadline = Date.now.addingTimeInterval(20)
        while Date.now < deadline {
            if isLive() { return true }
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return false
            }
        }
        return isLive()
    }

    /// Always LaunchServices, never activate(): only a reopen hands a headless Planote its window.
    func activatePlanote() {
        guard let appURL = planoteAppURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        Task {
            _ = try? await NSWorkspace.shared.openApplication(
                at: appURL, configuration: configuration)
        }
    }

    /// A write queues first and waits second: a timeout leaves the command for the next launch.
    func send(
        _ command: TodoBridgeCommand,
        timeout: Duration = .seconds(12)
    ) async throws -> TodoBridgeResult {
        guard planoteAppURL != nil else { throw SendError.planoteNotInstalled }
        if !isLive() {
            let launched = await launchPlanoteInBackground()
            try Task.checkCancellation()
            guard launched else {
                _ = try? store.writeCommand(command)
                throw SendError.launchTimedOut
            }
        }
        try store.writeCommand(command)
        let clock = ContinuousClock()
        let resultDeadline = clock.now.advanced(by: timeout)
        var result: TodoBridgeResult?
        while clock.now < resultDeadline {
            if let pending = loadResult(for: command.requestID) {
                result = pending
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard let result else { throw SendError.resultTimedOut }
        guard result.ok else {
            throw SendError.commandRejected(code: result.errorCode, message: result.errorMessage)
        }
        return try await awaitPublishedRevision(result, clock: clock)
    }

    private var planoteVersion: String? {
        guard let appURL = planoteAppURL else { return nil }
        return (Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String)
    }

    /// The result names the revision carrying the change, so the read model is confirmed.
    private func awaitPublishedRevision(
        _ result: TodoBridgeResult,
        clock: ContinuousClock
    ) async throws -> TodoBridgeResult {
        let deadline = clock.now.advanced(by: .seconds(3))
        var sawSnapshot = false
        while clock.now < deadline {
            try Task.checkCancellation()
            if let snapshot = loadSnapshot() {
                sawSnapshot = true
                if snapshot.revision >= result.revision { return result }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard sawSnapshot else { throw SendError.invalidSnapshot }
        return result
    }
}
