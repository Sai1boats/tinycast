import AppKit
import SwiftUI

@MainActor
@Observable
final class PlanoteCoordinator {
    private let settings: AppSettings
    private let index: AppIndex
    private let bridge: TodoBridgeClient
    let repository: PlanoteNoteRepository
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var serviceTask: Task<Void, Never>?
    @ObservationIgnored private var window: PlanoteNoteWindowController?
    @ObservationIgnored private var openingTask: Task<Void, Never>?
    private(set) var session: PlanoteNoteSession?
    private(set) var notes: [PlanoteNoteSummary] = []
    private(set) var isRunning = false
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    var isInstalled: Bool { bridge.planoteAppURL != nil }

    init(settings: AppSettings, index: AppIndex, bridge: TodoBridgeClient) {
        self.settings = settings
        self.index = index
        self.bridge = bridge
        repository = PlanoteNoteRepository(
            directory: bridge.bridgeDirectoryURL.appending(path: "Notes"),
            drafts: AppPaths.applicationSupport().appending(path: "PlanoteDrafts"))
    }

    func applyEnabled() {
        generation &+= 1
        refreshTask?.cancel()
        if settings.planoteNotesEnabled { refresh() } else {
            index.setPlanoteNotes([])
            window?.hide()
        }
    }

    func refresh(startIfNeeded: Bool = false) {
        refreshTask?.cancel()
        let generation = generation
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                if startIfNeeded, settings.planoteNotesEnabled, settings.planoteServiceEnabled {
                    try await ensureService()
                }
                let summaries = try await repository.list()
                guard !Task.isCancelled, generation == self.generation else { return }
                notes = summaries
                isRunning = bridge.isPlanoteRunning
                if settings.planoteNotesEnabled { index.setPlanoteNotes(summaries) }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func applyServiceEnabled() {
        serviceTask?.cancel()
        serviceTask = Task { [weak self] in
            guard let self else { return }
            if settings.planoteServiceEnabled { await startService() } else { await stopService() }
        }
    }

    func startService() async {
        guard !isWorking else { return }
        settings.planoteServiceEnabled = true
        isWorking = true
        defer { isWorking = false }
        let started = await bridge.launchPlanoteInBackground()
        isRunning = bridge.isPlanoteRunning
        errorMessage = started ? nil : String(localized: "Planote could not start.")
        refresh()
    }

    func stopService() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await session?.flush()
        settings.planoteServiceEnabled = false
        if !bridge.terminatePlanote() {
            errorMessage = String(localized: "Planote could not stop. Close its open dialogs and try again.")
            return
        }
        for _ in 0..<30 {
            if !bridge.isPlanoteRunning { break }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
        }
        isRunning = bridge.isPlanoteRunning
        errorMessage = isRunning
            ? String(localized: "Planote could not stop. Close its open dialogs and try again.") : nil
    }

    func ensureService() async throws {
        guard settings.planoteServiceEnabled else {
            throw CocoaError(.userCancelled, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Planote service is stopped. Start it in Planote settings to save.")
            ])
        }
        guard await bridge.launchPlanoteInBackground() else {
            throw CocoaError(.fileReadUnknown, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Planote could not start.")
            ])
        }
    }

    func open(_ id: UUID) {
        guard settings.planoteNotesEnabled else { return }
        openingTask?.cancel()
        openingTask = Task { [weak self] in
            guard let self else { return }
            await session?.flush()
            guard !Task.isCancelled else { return }
            if let session, session.noteID == id {
                await session.reloadIfClean()
                guard !Task.isCancelled else { return }
                showWindow()
                return
            }
            if session?.isDirty == true {
                errorMessage = String(localized: "Save the current draft before opening another note.")
                showWindow()
                return
            }
            do {
                if settings.planoteServiceEnabled {
                    do { try await ensureService() } catch { errorMessage = error.localizedDescription }
                }
                let note = try await repository.load(id)
                let draft = try await repository.loadDraft(id)
                guard !Task.isCancelled, settings.planoteNotesEnabled else { return }
                session = PlanoteNoteSession(note: note, draft: draft, repository: repository, coordinator: self)
                errorMessage = nil
                showWindow()
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                showWindow()
            }
        }
    }

    func openPlanote() { bridge.activatePlanote() }

    func hide() {
        window?.hide()
        session?.scheduleSave(immediately: true)
    }

    func prepareForTermination() async {
        openingTask?.cancel()
        refreshTask?.cancel()
        serviceTask?.cancel()
        await session?.flush()
    }

    private func showWindow() {
        if window == nil { window = PlanoteNoteWindowController(coordinator: self, settings: settings) }
        window?.show()
    }
}
