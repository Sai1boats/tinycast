import AppKit
import Observation
import SwiftUI

@main
@MainActor
struct TodosUITests {
    static func main() async throws {
        _ = NSApplication.shared
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let paths = TodoBridgePaths(homeDirectory: home)
        try FileManager.default.createDirectory(at: paths.baseURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let snapshot = fixture()
        try TodoBridgeProtocol.makeEncoder().encode(snapshot).write(to: paths.snapshotURL)
        let status = TodoBridgeStatus(
            schemaVersion: 1, pid: ProcessInfo.processInfo.processIdentifier,
            startedAt: .now, lastHeartbeatAt: .now, revision: 1)
        try TodoBridgeProtocol.makeEncoder().encode(status).write(to: paths.statusURL)
        let core = AppCore()
        let settings = AppSettings()
        let coordinator = TodosCoordinator(
            bridge: TodoBridgeClient(paths: paths), settings: settings, appIndex: AppIndex(), core: core)
        await coordinator.refresh()
        precondition(coordinator.snapshot == snapshot)
        let host = NSHostingView(rootView: TodosView().environment(coordinator))
        host.sizingOptions = []
        let window = TodosPanel(content: host, size: Theme.Size.todosWindow, styleMask: [.titled, .closable])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.setFrameOrigin(NSPoint(x: 50, y: 50))
        window.orderFront(nil)
        defer { window.close(); coordinator.hide() }
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            window.appearance = NSAppearance(named: appearance)
            for (sizeName, size) in [("default", Theme.Size.todosWindow), ("minimum", Theme.Size.todosWindowMinimum)] {
                window.setContentSize(size)
                coordinator.cancelEditing()
                try await settle(host)
                checkBackdrop(host)
                try capture(host, name: "list-\(name)-\(sizeName)")
                precondition(fields(in: host).filter(\.isEditable).isEmpty, "List has no editing fields")
                coordinator.beginEditing(snapshot.tasks[0])
                try await settle(host)
                try capture(host, name: "edit-\(name)-\(sizeName)")
                try checkEditor(host, title: snapshot.tasks[0].title)
                coordinator.updateDraft(.new(defaultSectionID: nil, now: .now))
                try await settle(host)
                try checkEditor(host, title: "")
                precondition(!coordinator.editorDraftBinding.wrappedValue.canSave)
                try capture(host, name: "new-\(name)-\(sizeName)")
            }
        }
        coordinator.beginEditing(snapshot.tasks[0])
        try await settle(host)
        guard let title = fields(in: host).first(where: { $0.stringValue == snapshot.tasks[0].title }) else {
            preconditionFailure("Missing task title")
        }
        title.stringValue = "Edited task title"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: title)
        try await settle(host)
        precondition(coordinator.editorDraft?.title == "Edited task title", "Native title edits reach the draft")
        guard let notes = editors(in: host).first else { preconditionFailure("Missing notes") }
        notes.string = "# Updated notes\nKeep **Markdown**."
        notes.didChangeText()
        try await settle(host)
        precondition(coordinator.editorDraft?.notesMarkdown == notes.string, "Native notes preserve Markdown")
        coordinator.hide()
        precondition(coordinator.editorDraft?.title == "Edited task title", "Hide preserves the draft")
        coordinator.cancelEditing()
        precondition(coordinator.editorDraft == nil && !coordinator.isShowingEditor)
        window.orderOut(nil)
        window.contentView = nil
        try await focusBehavior(coordinator, task: snapshot.tasks[0])
        try await rowActions(snapshot.tasks[0])
        precondition(!FileManager.default.fileExists(atPath: paths.commandsDirectory.path), "No real task mutations")
        print("Todos: native list/edit/create, dark/light, default/minimum, field bindings and separate row actions passed")
    }

    static func focusBehavior(
        _ coordinator: TodosCoordinator, task: TodoBridgeTask
    ) async throws {
        coordinator.show()
        guard let panel = NSApp.windows.first(where: { $0 is TodosPanel && $0.isVisible }),
              let root = panel.contentView else { preconditionFailure("Missing todo panel") }
        defer { coordinator.hide(); panel.close() }
        try await settle(root)
        precondition(panel.firstResponder === panel, "Opening the list does not focus Refresh")
        panel.selectNextKeyView(nil)
        try await settle(root)
        precondition(panel.firstResponder !== panel, "Tab still reaches the controls")
        coordinator.hide()
        coordinator.show()
        try await settle(root)
        precondition(panel.firstResponder === panel, "Reopening the list keeps actions unfocused")
        coordinator.beginEditing(task)
        try await settle(root)
        precondition(!(panel.firstResponder is NSTextView), "Viewing a task does not select its title")
        coordinator.cancelEditing()
        try await settle(root)
        coordinator.createTodo()
        try await settle(root)
        guard let title = fields(in: root).first(where: { $0.isEditable && $0.font?.pointSize == 22 }),
              let editor = title.currentEditor() else { preconditionFailure("New title accepts typing") }
        precondition(panel.firstResponder === editor, "A new task focuses its empty title")
        precondition(editor.selectedRange.length == 0, "An empty title has only an insertion point")
        coordinator.cancelEditing()
    }

    static func settle(_ root: NSView) async throws {
        try await Task.sleep(for: .milliseconds(300))
        root.layoutSubtreeIfNeeded()
    }

    static func checkEditor(_ root: NSView, title: String) throws {
        let inputs = fields(in: root).filter(\.isEditable)
        precondition(inputs.contains { $0.stringValue == title }, "Title field mounts")
        precondition(editors(in: root).count == 1, "Exactly one native Markdown editor")
        precondition(inputs.first { $0.stringValue == title }?.font?.pointSize == 22,
                     "Task titles use the balanced 22-point heading")
        precondition(editors(in: root).first?.font?.pointSize == 13,
                     "Markdown uses the 13-point body size")
        for input in inputs where input.stringValue != title {
            precondition(input.font?.pointSize == 13, "Subtask inputs match the 13-point body")
        }
        for input in inputs {
            let frame = input.convert(input.bounds, to: root)
            precondition(frame.width > 0 && frame.minX >= 0 && frame.maxX <= root.bounds.width + 1,
                         "Fields stay within the narrow panel: \(frame)")
        }
    }

    static func checkBackdrop(_ root: NSView) {
        let materials = descendants(in: root).compactMap { $0 as? NSVisualEffectView }
        precondition(materials.contains {
            $0.blendingMode == .behindWindow && $0.material == .hudWindow && $0.state == .active
        }, "The task sheet blurs the desktop even when inactive")
        precondition(root.window?.isOpaque == false, "The panel permits backdrop compositing")
    }

    static func descendants(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(in: $0) }
    }

    static func rowActions(_ task: TodoBridgeTask) async throws {
        var opened = 0
        var completions = 0
        let row = TodoRowView(task: task, label: nil, isSyncing: false,
                              onToggle: { _ in completions += 1 }, onOpen: { opened += 1 })
        let host = NSHostingView(rootView: row)
        host.sizingOptions = []
        let window = TodosPanel(content: host, size: CGSize(width: 420, height: 100), styleMask: [.borderless])
        window.setContentSize(CGSize(width: 420, height: 100))
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await settle(host)
        try capture(host, name: "row-actions")
        for point in [NSPoint(x: 13, y: 60), NSPoint(x: 200, y: 60)] {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(
                    with: type, location: point, modifierFlags: [], timestamp: 0,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                    clickCount: 1, pressure: 1) else { preconditionFailure("Missing click event") }
                window.sendEvent(event)
            }
            try await settle(host)
            if point.x < 20 {
                precondition(completions == 1 && opened == 0, "Completing never opens the editor: \(completions), \(opened)")
            } else {
                precondition(completions == 1 && opened == 1, "Opening never completes a task")
            }
        }
    }

    static func fields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { fields(in: $0) }
    }

    static func editors(in view: NSView) -> [NSTextView] {
        (view as? NSTextView).map { $0.isFieldEditor ? [] : [$0] } ?? view.subviews.flatMap { editors(in: $0) }
    }

    static func capture(_ root: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["TINYCAST_TODO_PREVIEW_DIRECTORY"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
            preconditionFailure("Cannot render todo view")
        }
        root.cacheDisplay(in: root.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            preconditionFailure("Cannot encode todo view")
        }
        try png.write(to: directory.appending(path: name + ".png"))
    }

    static func fixture() -> TodoBridgeSnapshot {
        let inbox = TodoBridgeBoardSection(id: UUID(), name: "收件箱", isInbox: true)
        let section = TodoBridgeBoardSection(id: UUID(), name: "工作", isInbox: false)
        let label = TodoBridgeLabel(id: UUID(), name: "设计", colorHex: "B7A2E5")
        let titles = ["整理待办组件设计", "补齐空状态文案", "确认发布检查清单", "整理本周会议记录"]
        let tasks = titles.enumerated().map { index, title in
            TodoBridgeTask(
                id: UUID(), title: title, notes: "对比查看、编辑和新增的布局。",
                notesMarkdown: "对比查看、编辑和新增的布局。\n\n重点检查：信息层级、留白、操作位置。",
                startDate: nil, dueDate: Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970))
                    .addingTimeInterval(Double(index - 1) * 86_400),
                bucket: .today, boardSectionID: index < 2 ? nil : section.id, labelID: label.id,
                isCompleted: false, subtasks: [
                    TodoBridgeSubtask(id: UUID(), title: "梳理现有功能", isCompleted: true),
                    TodoBridgeSubtask(id: UUID(), title: "比较三套设计方案", isCompleted: false),
                    TodoBridgeSubtask(id: UUID(), title: "确认最终方向", isCompleted: false)
                ])
        }
        return TodoBridgeSnapshot(schemaVersion: 1, revision: 1, generatedAt: Date(timeIntervalSince1970: 0),
                                  tasks: tasks, labels: [label], boardSections: [inbox, section])
    }
}

@MainActor @Observable final class AppCore {}
@MainActor @Observable final class AppSettings { var todosEnabled = true }
@MainActor final class AppIndex {
    enum Command { case showTodos, createTodo }
    func setCommandsVisible(_ commands: [Command], _ visible: Bool) {}
}

enum SystemSymbolName { static func resolve(_ name: String) -> String { name } }
enum PopoverMenuIcon {
    case blank, symbol(String), asset(String), file(String), thumbnail(id: UUID, data: Data)
}
struct MenuFileIcon: View { let path: String; var body: some View { EmptyView() } }
struct MenuThumbnail: View { let id: UUID; let data: Data; var body: some View { EmptyView() } }
