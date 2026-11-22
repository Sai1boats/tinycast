import SwiftUI

@MainActor @Observable
final class TodosCoordinator {
    private let repository: TodoRepository
    private let window: AppWindowController
    private let reminders: any TodoReminderScheduling
    private var waitingForDialog = false
    private var terminating = false
    private var requestedID: UUID?
    private let confirmDelete: (String, String) async -> Bool
    private var creationDraft: (title: String, parent: UUID?, reminder: Bool, date: Date)?
    var composerTitle: String { creationDraft?.title ?? draft }
    private(set) var board = TodoBoard()
    var items: [LocalTodo] { board.items }
    private(set) var project: String?
    private(set) var loaded = false
    private(set) var editingID: UUID?
    private(set) var parentID: UUID?
    private(set) var errorMessage: String?
    private(set) var canRetry = false
    private(set) var pending: Task<Void, Never>?
    var draft = ""
    private let requestProjectName: (String?) async -> String?
    var reminderEnabled = false
    var reminderDate = Date.now.addingTimeInterval(3600)
    var expanded: Set<UUID> = []

    init(repository: TodoRepository, activation: ActivationPolicy?, reminders: any TodoReminderScheduling,
         requestProjectName: @escaping (String?) async -> String?, confirmDelete: @escaping (String, String) async -> Bool) {
        self.repository = repository
        self.reminders = reminders
        self.requestProjectName = requestProjectName
        self.confirmDelete = confirmDelete
        window = AppWindowController(
            title: String(localized: "Local Todos"), contentSize: Theme.Size.todosWindow,
            minimumSize: Theme.Size.todosMinimum, resizable: true,
            autosaveName: "Local Todo Projects", activation: activation, closesOnEscape: true)
    }

    func show(itemID: UUID? = nil) {
        requestedID = itemID
        window.show(chrome: UtilityWindowChrome()) { TodosView().environment(self) }
        load()
        if pending == nil { revealRequestedItem() }
    }

    func close() { window.close() }

    func load() {
        guard !loaded else { return }
        perform {
            self.canRetry = true
            self.board = try await self.repository.load()
            self.loaded = true
            try await self.reminders.synchronize(self.items)
        }
    }

    func retry() {
        if loaded {
            perform {
                self.canRetry = true
                try await self.reminders.synchronize(self.items)
            }
        } else { load() }
    }

    func select(_ name: String?) {
        guard project != name else { return }
        project = name
        creationDraft = nil
        cancelEditing()
    }

    func addProject() {
        guard loaded else { return }
        perform {
            guard let name = await self.projectName(replacing: nil) else { return }
            var next = self.board
            if !next.projects.contains(name) {
                next.projects.append(name)
                try await self.persist(next)
            }
            self.select(name)
        }
    }

    func renameProject(_ original: String) {
        guard let index = board.projects.firstIndex(of: original) else { return }
        perform {
            guard let name = await self.projectName(replacing: original), name != original else { return }
            guard !self.board.projects.contains(name) else {
                self.errorMessage = String(localized: "A project with this name already exists.")
                return
            }
            var next = self.board
            next.projects[index] = name
            for index in next.items.indices where next.items[index].project == original {
                next.items[index].project = name
            }
            try await self.persist(next)
            if self.project == original { self.project = name }
        }
    }

    private func projectName(replacing original: String?) async -> String? {
        guard !terminating else { return nil }
        waitingForDialog = true
        defer { waitingForDialog = false }
        let input = await requestProjectName(original)
        guard !terminating, let name = input?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty else { return nil }
        return name
    }

    func deleteProject(_ name: String) {
        guard board.projects.contains(name) else { return }
        perform {
            let message = String(localized: "Tasks in “\(name)” will move to Inbox.")
            guard await self.approveDeletion(title: String(localized: "Delete project?"), message: message) else { return }
            var next = self.board
            next.projects.removeAll { $0 == name }
            for index in next.items.indices where next.items[index].project == name {
                next.items[index].project = nil
            }
            try await self.persist(next)
            if self.project == name { self.select(nil) }
        }
    }

    func addChild(to item: LocalTodo) {
        cancelEditing()
        parentID = item.id
        expanded.insert(item.id)
    }

    func edit(_ item: LocalTodo) {
        if editingID == nil { creationDraft = (draft, parentID, reminderEnabled, reminderDate) }
        editingID = item.id
        parentID = item.parentID
        draft = item.title
        reminderEnabled = item.reminder != nil
        reminderDate = item.reminder ?? Date.now.addingTimeInterval(3600)
    }

    func cancelEditing() {
        editingID = nil
        parentID = creationDraft?.parent
        draft = creationDraft?.title ?? ""
        reminderEnabled = creationDraft?.reminder ?? false
        reminderDate = creationDraft?.date ?? Date.now.addingTimeInterval(3600)
        creationDraft = nil
    }

    func submit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loaded, !title.isEmpty else { return }
        var next = board
        let previous = items.first { $0.id == editingID }
        let date = reminderEnabled ? reminderDate : nil
        let changedReminder = date != nil && previous?.reminder != date
        if changedReminder, let date, date <= Date() {
            errorMessage = TodoReminderError.past.localizedDescription
            return
        }
        if let index = next.items.firstIndex(where: { $0.id == editingID }) {
            next.items[index].title = title
            next.items[index].reminder = date
        } else {
            next.items.insert(LocalTodo(id: UUID(), title: title, isCompleted: false, project: project,
                                        parentID: parentID, reminder: date), at: 0)
            if let index = next.items.firstIndex(where: { $0.id == parentID }) { next.items[index].isCompleted = false }
        }
        perform {
            if changedReminder {
                guard !self.terminating else { return }
                self.waitingForDialog = true
                defer { self.waitingForDialog = false }
                try await self.reminders.authorize()
                guard !self.terminating else { return }
            }
            try await self.persist(next)
            self.cancelEditing()
        }
    }

    func toggle(_ item: LocalTodo) {
        var next = board
        let completed = !item.isCompleted
        for index in next.items.indices {
            let row = next.items[index]
            if row.id == item.id || (completed && row.parentID == item.id) || (!completed && row.id == item.parentID) {
                next.items[index].isCompleted = completed
            }
        }
        perform { try await self.persist(next) }
    }

    func move(_ item: LocalTodo, to project: String?) {
        var next = board
        for index in next.items.indices where next.items[index].id == item.id || next.items[index].parentID == item.id {
            next.items[index].project = project
        }
        perform {
            try await self.persist(next)
            if self.creationDraft?.parent == item.id { self.creationDraft = nil }
            if self.editingID == item.id || self.parentID == item.id { self.cancelEditing() }
        }
    }

    func delete(_ item: LocalTodo) {
        perform {
            guard await self.approveDeletion(title: String(localized: "Delete task?"), message: item.title) else { return }
            var next = self.board
            next.items.removeAll { $0.id == item.id || $0.parentID == item.id }
            try await self.persist(next)
            if self.creationDraft?.parent == item.id { self.creationDraft = nil }
            if self.editingID == item.id || self.parentID == item.id { self.cancelEditing() }
        }
    }

    private func approveDeletion(title: String, message: String) async -> Bool {
        guard !terminating else { return false }
        waitingForDialog = true
        defer { waitingForDialog = false }
        let approved = await confirmDelete(title, message)
        return approved && !terminating
    }

    func finishForTermination() async {
        terminating = true
        if !waitingForDialog { await pending?.value }
    }

    private func persist(_ next: TodoBoard) async throws {
        try await repository.save(next)
        let previous = board
        board = next
        guard previous.items != next.items else { return }
        do { try await reminders.synchronize(next.items) } catch {
            canRetry = true
            errorMessage = error.localizedDescription
        }
    }

    private func revealRequestedItem() {
        guard let id = requestedID, let item = items.first(where: { $0.id == id }) else { return }
        requestedID = nil
        select(item.project)
        expanded.insert(item.parentID ?? id)
        edit(item)
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !terminating, pending == nil else { return }
        canRetry = false
        errorMessage = nil
        pending = Task {
            defer {
                pending = nil
                revealRequestedItem()
            }
            do { try await operation() } catch { errorMessage = error.localizedDescription }
        }
    }
}
