import Foundation
import Observation

@MainActor
@Observable
final class PlanoteNoteSession {
    private(set) var base: PlanoteNote
    var title: String { didSet { scheduleSave() } }
    var markdown: String { didSet { scheduleSave() } }
    private(set) var epoch = 0
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var hasConflict = false
    @ObservationIgnored private let repository: PlanoteNoteRepository
    @ObservationIgnored private weak var coordinator: PlanoteCoordinator?
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var saving: Task<Void, Never>?
    @ObservationIgnored private var pending: PlanoteNoteCommand?

    var noteID: UUID { base.summary.id }
    var isDirty: Bool { title != base.summary.title || markdown != base.markdown }
    var input: NoteEditorInput {
        NoteEditorInput(id: NoteID(rawValue: noteID.uuidString), source: markdown, epoch: epoch)
    }

    init(
        note: PlanoteNote, draft: PlanoteNoteDraft?, repository: PlanoteNoteRepository,
        coordinator: PlanoteCoordinator
    ) {
        base = note
        self.repository = repository
        self.coordinator = coordinator
        pending = draft?.pendingCommand
        title = draft?.title ?? note.summary.title
        markdown = draft?.markdown ?? note.markdown
        if let draft, draft.expectedVersion != note.summary.version, isDirty, pending == nil {
            hasConflict = true
            errorMessage = String(localized: "Planote changed this note. Your recovered draft is kept.")
        }
    }

    func scheduleSave(immediately: Bool = false) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            if !immediately {
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            }
            await self?.flush()
        }
    }

    func flush() async {
        if let saving { await saving.value; return }
        guard isDirty || pending != nil else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await saveDraft()
        }
        saving = task
        await task.value
        saving = nil
        if isDirty, errorMessage == nil { await flush() }
    }

    private func saveDraft() async {
        isSaving = true
        defer { isSaving = false }
        do {
            while isDirty || pending != nil {
                let draft = PlanoteNoteCommand(
                    requestID: UUID(), noteID: noteID, expectedVersion: base.summary.version,
                    title: title, markdown: markdown)
                try await preserveDraft()
                if hasConflict { break }
                guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = String(localized: "A note title is required.")
                    break
                }
                guard let coordinator else { throw CancellationError() }
                try await coordinator.ensureService()
                let command = pending ?? draft
                pending = command
                try await preserveDraft()
                let result = try await repository.send(command)
                if let message = result.errorMessage {
                    pending = nil
                    hasConflict = result.errorCode == "conflict" || result.errorCode == "noteNotFound"
                    errorMessage = message
                    break
                }
                guard let saved = result.note, saved.summary.id == noteID else {
                    throw CocoaError(.coderReadCorrupt)
                }
                pending = nil
                base = saved
                errorMessage = nil
                coordinator.refresh()
            }
            if !isDirty { try await repository.removeDraft(noteID) }
        } catch { errorMessage = error.localizedDescription }
        if isDirty || pending != nil {
            do { try await preserveDraft() } catch { errorMessage = error.localizedDescription }
        }
    }

    private func preserveDraft() async throws {
        try await repository.preserve(PlanoteNoteDraft(
            noteID: noteID, expectedVersion: base.summary.version,
            title: title, markdown: markdown, pendingCommand: pending))
    }

    func reloadIfClean() async {
        guard !isDirty, !isSaving else { return }
        let previous = base
        do {
            let latest = try await repository.load(noteID)
            guard !isDirty, !isSaving, base == previous, latest != base else { return }
            base = latest
            title = latest.summary.title
            markdown = latest.markdown
            epoch &+= 1
        } catch { errorMessage = error.localizedDescription }
    }

    func reloadKeepingDraft() async {
        await flush()
        guard !isSaving else { return }
        let originalTitle = title
        let originalMarkdown = markdown
        do {
            let latest = try await repository.load(noteID)
            if isDirty {
                try await repository.archiveDraft(title: originalTitle, markdown: originalMarkdown)
            }
            guard title == originalTitle, markdown == originalMarkdown, !isSaving else { return }
            base = latest
            title = latest.summary.title
            markdown = latest.markdown
            epoch &+= 1
            hasConflict = false
            pending = nil
            errorMessage = nil
            try await repository.removeDraft(noteID)
        } catch { errorMessage = error.localizedDescription }
    }
}
