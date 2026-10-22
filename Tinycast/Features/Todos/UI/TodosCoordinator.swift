import AppKit
import SwiftUI

@MainActor
@Observable
final class TodosCoordinator {
    enum Connection: Equatable {
        case checking
        case live
        case offline
        case notInstalled
        case syncing
    }

    private let bridge: TodoBridgeClient
    private let settings: AppSettings
    private let appIndex: AppIndex
    private unowned let core: AppCore
    @ObservationIgnored private lazy var windowController = TodosWindowController(
        coordinator: self, core: core, settings: settings)
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var operations: [Int: Task<TodoBridgeResult, any Error>] = [:]
    @ObservationIgnored private var nextOperationID = 0
    /// Reused across retries so a timed-out create cannot become a second task.
    @ObservationIgnored private var pendingCreateTaskID: UUID?

    private(set) var connection: Connection = .checking
    private(set) var snapshot: TodoBridgeSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isShowingCompleted = true
    private(set) var isShowingEditor = false
    private(set) var editorDraft: TodoEditorDraft?
    private(set) var pendingCount = 0
    private(set) var lastHeartbeat: Date?

    init(bridge: TodoBridgeClient, settings: AppSettings, appIndex: AppIndex, core: AppCore) {
        self.bridge = bridge
        self.settings = settings
        self.appIndex = appIndex
        self.core = core
    }

    var bridgeDirectoryPath: String { bridge.bridgeDirectoryURL.path }
    var isPlanoteInstalled: Bool { bridge.planoteAppURL != nil }
    var isPlanoteRunning: Bool { bridge.isPlanoteRunning }
    /// The editor writes through this so a draft survives every path that is not Cancel or a save.
    var editorDraftBinding: Binding<TodoEditorDraft> {
        Binding(
            get: { [weak self] in
                self?.editorDraft ?? TodoEditorDraft.new(defaultSectionID: nil, now: .now)
            },
            set: { [weak self] in self?.updateDraft($0) })
    }

    func applyEnabled() {
        appIndex.setCommandsVisible([.showTodos, .createTodo], settings.todosEnabled)
        guard settings.todosEnabled else {
            refreshGeneration &+= 1
            refreshTask?.cancel()
            refreshTask = nil
            for (_, task) in operations { task.cancel() }
            operations.removeAll()
            pendingCount = 0
            windowController.hide()
            errorMessage = nil
            connection = .checking
            return
        }
    }

    /// The command is a toggle: a second press puts the panel away.
    func toggle() {
        if windowController.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard settings.todosEnabled else { return }
        windowController.show(focus: true)
        startRefreshLoop()
        Task { await refresh() }
    }

    func hide() {
        refreshGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        windowController.hide()
    }

    func createTodo() {
        guard settings.todosEnabled else { return }
        pendingCreateTaskID = nil
        updateDraft(TodoEditorDraft.new(defaultSectionID: nil, now: .now))
        isShowingEditor = true
        show()
    }

    /// Safe to call repeatedly: one read of the bridge, then the display state follows it.
    func refresh() async {
        let generation = refreshGeneration
        isLoading = snapshot == nil
        // One hop, so the empty window can draw its loading state before the read lands.
        await Task.yield()
        let newSnapshot = bridge.loadSnapshot()
        let status = bridge.loadStatus()
        let newConnection = bridge.connection()
        guard generation == refreshGeneration, settings.todosEnabled else {
            isLoading = false
            return
        }
        if let newSnapshot {
            snapshot = newSnapshot
            lastHeartbeat = status?.lastHeartbeatAt
        } else if let status {
            lastHeartbeat = status.lastHeartbeatAt
        }
        isLoading = false
        guard pendingCount == 0 else { return }
        connection = Self.displayConnection(for: newConnection)
    }

    func beginEditing(_ task: TodoBridgeTask) {
        pendingCreateTaskID = nil
        updateDraft(TodoEditorDraft(task: task))
        isShowingEditor = true
    }

    func cancelEditing() {
        pendingCreateTaskID = nil
        isShowingEditor = false
        editorDraft = nil
    }

    func updateDraft(_ draft: TodoEditorDraft) {
        editorDraft = draft
    }

    func save(_ draft: TodoEditorDraft) async {
        guard settings.todosEnabled, draft.canSave else { return }
        guard let command = command(for: draft) else { return }
        do {
            _ = try await run(command)
            pendingCreateTaskID = nil
            editorDraft = nil
            isShowingEditor = false
        } catch {
            if !Self.isCancellation(error) { errorMessage = Self.message(for: error) }
        }
        await refresh()
    }

    func setCompleted(_ task: TodoBridgeTask, _ completed: Bool) async {
        guard settings.todosEnabled else { return }
        let command = TodoBridgeCommand(
            schemaVersion: TodoBridgeProtocol.schemaVersion,
            requestID: UUID(),
            kind: .setCompleted,
            sentAt: .now,
            task: nil,
            taskID: task.id,
            isCompleted: completed)
        do {
            _ = try await run(command)
        } catch {
            if !Self.isCancellation(error) { errorMessage = Self.message(for: error) }
        }
        await refresh()
    }

    func toggleCompletedVisibility() {
        isShowingCompleted.toggle()
    }

    func openPlanote() {
        bridge.activatePlanote()
    }

    func openBridgeFolder() {
        NSWorkspace.shared.open(bridge.bridgeDirectoryURL)
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    /// One in-flight command per call, cancellable, so disabling cannot leave one waiting.
    private func run(_ command: TodoBridgeCommand) async throws -> TodoBridgeResult {
        nextOperationID &+= 1
        let id = nextOperationID
        pendingCount &+= 1
        connection = .syncing
        let task = Task { [bridge] in try await bridge.send(command) }
        operations[id] = task
        defer {
            operations[id] = nil
            pendingCount = max(0, pendingCount &- 1)
        }
        return try await task.value
    }

    private func startRefreshLoop() {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self, generation == self.refreshGeneration,
                    self.settings.todosEnabled
                else {
                    return
                }
                await self.refresh()
            }
        }
    }

    private static func displayConnection(
        for connection: TodoBridgeClient.Connection
    ) -> Connection {
        switch connection {
        case .checking: return .checking
        case .live: return .live
        case .offline: return .offline
        case .notInstalled: return .notInstalled
        }
    }

    private func command(for draft: TodoEditorDraft) -> TodoBridgeCommand? {
        if draft.isNew {
            let taskID = pendingCreateTaskID ?? UUID()
            pendingCreateTaskID = taskID
            return TodoBridgeCommand(
                schemaVersion: TodoBridgeProtocol.schemaVersion,
                requestID: UUID(),
                kind: .create,
                sentAt: .now,
                task: draft.createPayload(taskID: taskID),
                taskID: nil,
                isCompleted: nil)
        }
        guard let payload = draft.updatePayload() else { return nil }
        return TodoBridgeCommand(
            schemaVersion: TodoBridgeProtocol.schemaVersion,
            requestID: UUID(),
            kind: .update,
            sentAt: .now,
            task: payload,
            taskID: nil,
            isCompleted: nil)
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || Task.isCancelled
    }

    private static func message(for error: any Error) -> String {
        guard let sendError = error as? TodoBridgeClient.SendError else {
            return error.localizedDescription
        }
        switch sendError {
        case .serviceStopped:
            return String(localized: "Planote service is stopped. Start it in Planote settings to save.")
        case .planoteNotInstalled:
            return String(localized: "Planote is not installed.")
        case .launchTimedOut:
            return String(localized: "Planote did not open in time. The change is queued.")
        case .resultTimedOut:
            return String(localized: "Planote did not answer in time. The change is queued.")
        case .commandRejected(_, let message):
            return message ?? String(localized: "Planote rejected the change.")
        case .invalidSnapshot:
            return String(localized: "Planote's task list could not be read.")
        }
    }
}
