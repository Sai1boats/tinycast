import Foundation

/// Editor state for one todo. The UI binds to its fields; payloads are built from it on save.
struct TodoEditorDraft: Equatable {
    var taskID: UUID?
    var title: String
    var notesMarkdown: String = ""
    /// Matching it means no edit: the update omits notes, so Planote keeps note, RTF and images.
    var initialNotesMarkdown: String = ""
    var hasDueDate: Bool
    var dueDate: Date
    /// Carried through untouched: the editor has no start-date field, so updates must keep it.
    var startDate: Date?
    var boardSectionID: UUID?
    var labelID: UUID?
    var subtasks: [TodoBridgeSubtask]

    static func new(defaultSectionID: UUID?, now: Date) -> TodoEditorDraft {
        TodoEditorDraft(
            taskID: nil, title: "", notesMarkdown: "", initialNotesMarkdown: "",
            hasDueDate: false, dueDate: now, startDate: nil,
            boardSectionID: defaultSectionID, labelID: nil, subtasks: [])
    }

    var isNew: Bool { taskID == nil }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createPayload(taskID: UUID) -> TodoBridgeTaskPayload {
        let trimmed = notesMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return payload(id: taskID, notesMarkdown: trimmed.isEmpty ? nil : trimmed)
    }

    func updatePayload() -> TodoBridgeTaskPayload? {
        guard let taskID else { return nil }
        guard notesMarkdown != initialNotesMarkdown else {
            return payload(id: taskID, notesMarkdown: nil)
        }
        return payload(
            id: taskID,
            notesMarkdown: notesMarkdown.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    mutating func addSubtask() {
        subtasks.append(TodoBridgeSubtask(id: UUID(), title: "", isCompleted: false))
    }

    mutating func removeSubtask(id: UUID) {
        subtasks.removeAll { $0.id == id }
    }

    mutating func toggleSubtask(id: UUID) {
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[index].isCompleted.toggle()
    }

    private func payload(id: UUID, notesMarkdown: String?) -> TodoBridgeTaskPayload {
        TodoBridgeTaskPayload(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            dueDate: hasDueDate ? dueDate : nil,
            boardSectionID: boardSectionID,
            labelID: labelID,
            subtasks: subtasks,
            notesMarkdown: notesMarkdown)
    }
}

extension TodoEditorDraft {
    /// Undated tasks seed the picker with the epoch, unused while hasDueDate is off.
    init(task: TodoBridgeTask) {
        let notes = task.notesMarkdown ?? task.notes
        self.init(
            taskID: task.id, title: task.title, notesMarkdown: notes, initialNotesMarkdown: notes,
            hasDueDate: task.dueDate != nil,
            dueDate: task.dueDate ?? Date(timeIntervalSince1970: 0),
            startDate: task.startDate,
            boardSectionID: task.boardSectionID, labelID: task.labelID, subtasks: task.subtasks)
    }
}
