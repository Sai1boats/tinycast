import AppKit
import SwiftUI

@main @MainActor
struct LocalTodosTest {
    static func main() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = TodoRepository(url: directory.appending(path: "todos.json"))
        let reminders = TestReminders()
        var allowDelete = false
        let todos = TodosCoordinator(
            repository: repository, activation: nil, reminders: reminders, requestProjectName: { _ in nil }
        ) { _, _ in allowDelete }
        todos.load()
        await todos.pending?.value
        precondition(todos.loaded && todos.items.isEmpty)
        try await preview(todos)
        todos.draft = "  "
        todos.submit()
        precondition(todos.pending == nil)
        todos.draft = "  Review release notes  "
        todos.submit()
        todos.submit()
        await todos.pending?.value
        precondition(todos.items.count == 1 && todos.items[0].title == "Review release notes")
        let first = todos.items[0]
        todos.edit(first)
        todos.draft = "Review the checklist"
        todos.submit()
        await todos.pending?.value
        todos.toggle(todos.items[0])
        await todos.pending?.value
        todos.draft = "Check Chinese input 中文"
        todos.submit()
        await todos.pending?.value
        let reopened = TodosCoordinator(
            repository: repository, activation: nil, reminders: reminders, requestProjectName: { _ in nil }
        ) { _, _ in false }
        reopened.load()
        await reopened.pending?.value
        precondition(reopened.items == todos.items && reopened.items[1].isCompleted)
        precondition(reopened.items[1].id == first.id && reopened.items[1].title == "Review the checklist")
        try await projectChecks(directory: directory)
        todos.toggle(todos.items[1])
        await todos.pending?.value
        precondition(!todos.items[1].isCompleted)
        todos.delete(first)
        await todos.pending?.value
        precondition(todos.items.count == 2)
        allowDelete = true
        todos.delete(first)
        await todos.pending?.value
        let persisted = try await repository.load().items
        precondition(persisted == todos.items && persisted.count == 1 && persisted[0].id != first.id)
        todos.draft = "Save before quitting"
        todos.submit()
        await todos.finishForTermination()
        let atQuit = try await repository.load().items
        precondition(atQuit.first?.title == "Save before quitting")

        try FileManager.default.removeItem(at: repository.url)
        try FileManager.default.createDirectory(at: repository.url, withIntermediateDirectories: false)
        reopened.draft = "Retry this task"
        let beforeFailure = reopened.items
        reopened.submit()
        await reopened.pending?.value
        precondition(reopened.errorMessage != nil && reopened.items == beforeFailure && reopened.draft == "Retry this task")
        try FileManager.default.removeItem(at: repository.url)
        try Data("invalid".utf8).write(to: repository.url)
        let damaged = TodosCoordinator(
            repository: repository, activation: nil, reminders: reminders, requestProjectName: { _ in nil }
        ) { _, _ in false }
        damaged.load()
        await damaged.pending?.value
        damaged.draft = "Keep the original file"
        damaged.submit()
        let bytes = try Data(contentsOf: repository.url)
        precondition(!damaged.loaded && damaged.errorMessage != nil && bytes == Data("invalid".utf8))
    }

    static func projectChecks(directory: URL) async throws {
        let url = directory.appending(path: "legacy.json")
        let id = UUID()
        let legacy = #"[{"id":"\#(id.uuidString)","title":"Review release notes","isCompleted":false}]"#
        try Data(legacy.utf8).write(to: url)
        let reminders = TestReminders()
        let repository = TodoRepository(url: url)
        var projectName: String?
        var approve = false
        let todos = TodosCoordinator(
            repository: repository, activation: nil, reminders: reminders, requestProjectName: { _ in projectName }
        ) { _, _ in approve }
        todos.load()
        await todos.pending?.value
        precondition(todos.items.first?.id == id && todos.project == nil)
        todos.addProject()
        await todos.pending?.value
        precondition(todos.board.projects.isEmpty && todos.project == nil)
        projectName = " Release "
        todos.addProject()
        await todos.pending?.value
        let root = todos.items[0]
        todos.move(root, to: "Release")
        await todos.pending?.value
        todos.addChild(to: root)
        todos.draft = "Verify the signed build"
        todos.reminderEnabled = true
        todos.reminderDate = .distantPast
        todos.submit()
        precondition(todos.errorMessage != nil && todos.items.count == 1)
        todos.reminderDate = Date.now.addingTimeInterval(3600)
        reminders.allowed = false
        todos.submit()
        await todos.pending?.value
        precondition(todos.items.count == 1 && todos.errorMessage != nil && !todos.draft.isEmpty)
        reminders.allowed = true
        todos.submit()
        await todos.pending?.value
        let child = todos.items[0]
        precondition(child.parentID == id && child.project == "Release" && reminders.upcoming == [child.id])
        todos.draft = "Unsubmitted title"
        todos.edit(child)
        try await preview(todos)
        let revised = Date.now.addingTimeInterval(7200)
        todos.reminderDate = revised
        todos.submit()
        await todos.pending?.value
        let nextFire = TodoReminders.trigger(at: revised).nextTriggerDate()
        precondition(nextFire.map { abs($0.timeIntervalSince(revised)) < 1 } == true)
        precondition(todos.draft == "Unsubmitted title")
        let rescheduled = try await repository.load()
        precondition(rescheduled.items[0].reminder == revised && reminders.upcoming == [child.id])
        todos.edit(todos.items[0])
        todos.reminderEnabled = false
        todos.submit()
        await todos.pending?.value
        precondition(todos.items[0].reminder == nil && reminders.upcoming.isEmpty)
        todos.edit(child)
        todos.submit()
        await todos.pending?.value
        todos.toggle(root)
        await todos.pending?.value
        precondition(todos.items.allSatisfy(\.isCompleted) && reminders.upcoming.isEmpty)
        todos.toggle(todos.items[0])
        await todos.pending?.value
        precondition(todos.items.allSatisfy { !$0.isCompleted } && reminders.upcoming == [child.id])
        projectName = "Shipping"
        todos.renameProject("Release")
        await todos.pending?.value
        let renamed = try await repository.load()
        precondition(renamed.projects == ["Shipping"] && todos.project == "Shipping")
        precondition(renamed.items.count == 2 && renamed.items.allSatisfy { $0.project == "Shipping" })
        precondition(renamed.items[0].parentID == id && reminders.upcoming == [child.id])
        projectName = "Other"
        todos.addProject()
        await todos.pending?.value
        todos.renameProject("Shipping")
        await todos.pending?.value
        precondition(todos.errorMessage != nil && todos.board.projects == ["Shipping", "Other"])
        todos.select("Shipping")
        todos.deleteProject("Shipping")
        await todos.pending?.value
        precondition(todos.board.projects == ["Shipping", "Other"] && todos.project == "Shipping")
        approve = true
        todos.deleteProject("Shipping")
        await todos.pending?.value
        let saved = try await repository.load()
        precondition(saved.projects == ["Other"] && todos.project == nil && saved.items.allSatisfy { $0.project == nil })
        precondition(saved.items.count == 2 && reminders.upcoming == [child.id])
        todos.delete(root)
        await todos.pending?.value
        precondition(todos.items.isEmpty && reminders.upcoming.isEmpty)
    }

    static func preview(_ coordinator: TodosCoordinator) async throws {
        guard let path = ProcessInfo.processInfo.environment["TINYCAST_TODO_PREVIEW_DIRECTORY"] else { return }
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            for (label, size) in [("minimum", Theme.Size.todosMinimum), ("opening", Theme.Size.todosWindow)] {
                let root = NSHostingView(rootView: TodosView().environment(coordinator))
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
                                      backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: appearance)
                window.contentView = root
                window.setContentSize(size)
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(200))
                root.layoutSubtreeIfNeeded()
                guard let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                root.cacheDisplay(in: root.bounds, to: bitmap)
                let state = coordinator.items.isEmpty ? "empty" : "list"
                try bitmap.representation(using: .png, properties: [:])?.write(
                    to: URL(filePath: path).appending(path: "todos-\(state)-\(name)-\(label).png"))
                window.close()
            }
        }
    }
}

@MainActor private final class TestReminders: TodoReminderScheduling {
    var allowed = true
    var upcoming: [UUID] = []

    func authorize() async throws {
        if !allowed { throw TodoReminderError.denied }
    }

    func synchronize(_ items: [LocalTodo]) async throws {
        upcoming = items.filter { !$0.isCompleted && ($0.reminder ?? .distantPast) > Date() }.map(\.id)
    }
}
