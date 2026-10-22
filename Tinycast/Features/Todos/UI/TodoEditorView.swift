import SwiftUI

/// The in-panel editor: the list is replaced, the draft lives on the coordinator.
struct TodoEditorView: View {
    @Environment(TodosCoordinator.self) private var todos
    @FocusState private var titleFocused: Bool
    @State private var newSubtaskTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    backRow
                    titleField
                    notesEditor
                    properties
                    subtasksSection
                }
                .padding(.horizontal, Theme.Spacing.xxxl)
                .padding(.vertical, Theme.Spacing.xl)
            }
            errorText
            footer
        }
        .task {
            guard draft.wrappedValue.isNew else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            titleFocused = true
        }
    }

    private var draft: Binding<TodoEditorDraft> { todos.editorDraftBinding }

    private var backRow: some View {
        Button(action: todos.cancelEditing) {
            HStack(spacing: Theme.Spacing.sm) {
                SymbolImage(name: "chevron.left", size: Theme.Size.todosRowGlyph)
                Text(draft.wrappedValue.isNew
                    ? String(localized: "New Todo")
                    : String(localized: "Edit Todo"))
            }
            .font(Theme.Typography.todosDetail)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Back"))
        .help(String(localized: "Back"))
    }

    private var titleField: some View {
        TextField(String(localized: "What needs doing?"), text: draft.title)
            .font(Theme.Typography.todosEditorTitle)
            .foregroundStyle(Theme.Colors.textPrimary)
            .focused($titleFocused)
            .textFieldStyle(.plain)
            .accessibilityLabel(String(localized: "Task title"))
            .accessibilityIdentifier("todo-title")
            .onSubmit { save() }
    }

    private var notesEditor: some View {
        TextEditor(text: draft.notesMarkdown)
            .font(Theme.Typography.todosBody)
            .foregroundStyle(Theme.Colors.textSecondary)
            .lineSpacing(Theme.Size.todosNotesLineSpacing)
            .scrollContentBackground(.hidden)
            .frame(height: Theme.Size.todosNotesEditorHeight)
            .padding(.horizontal, -Theme.Size.todosNotesTextInset)
            .overlay(alignment: .topLeading) {
                if draft.wrappedValue.notesMarkdown.isEmpty {
                    Text(String(localized: "Add a note, supports Markdown"))
                        .font(Theme.Typography.todosBody)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.xs)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(String(localized: "Task Notes"))
            .accessibilityIdentifier("todo-notes")
    }

    private var properties: some View {
        VStack(spacing: 0) {
            propertyRule
            propertyRow("calendar", String(localized: "Due Date")) {
                Toggle(String(localized: "Add due date"), isOn: draft.hasDueDate)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .accessibilityIdentifier("todo-due-toggle")
            }
            if draft.wrappedValue.hasDueDate {
                DatePicker(
                    String(localized: "Due Date"),
                    selection: draft.dueDate,
                    displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(Theme.Typography.todosDetail)
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: Theme.Size.todosPropertyHeight)
                .accessibilityIdentifier("todo-due-date")
            }
            propertyRow("folder", String(localized: "Section")) {
                Picker(String(localized: "Section"), selection: sectionSelection) {
                    Text(String(localized: "Inbox")).tag(UUID?.none)
                    ForEach(sections, id: \.id) { section in
                        Text(section.name).tag(Optional(section.id))
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("todo-section")
            }
            propertyRow("tag", String(localized: "Label")) {
                Picker(String(localized: "Label"), selection: draft.labelID) {
                    Text(String(localized: "None")).tag(UUID?.none)
                    ForEach(labels, id: \.id) { label in
                        Text(label.name).tag(Optional(label.id))
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("todo-label")
            }
            propertyRule
        }
        .controlSize(.small)
    }

    private var propertyRule: some View {
        Rectangle()
            .fill(Theme.Colors.separator)
            .frame(height: Theme.Size.hairline)
    }

    private func propertyRow<Content: View>(
        _ symbol: String,
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            SymbolImage(name: symbol, size: Theme.Size.todosRowGlyph)
                .accessibilityHidden(true)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.md)
            content()
        }
        .font(Theme.Typography.todosDetail)
        .foregroundStyle(Theme.Colors.textSecondary)
        .frame(minHeight: Theme.Size.todosPropertyHeight)
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(String(localized: "Subtasks"))
                Spacer()
                Text(subtaskDetail)
                    .font(Theme.Typography.todosMetadata)
            }
            .font(Theme.Typography.todosDetail)
            .foregroundStyle(Theme.Colors.textSecondary)
            subtaskList
            addSubtaskRow
            if draft.wrappedValue.subtasks.isEmpty {
                Text(String(localized: "Break this task into smaller steps."))
                    .font(Theme.Typography.todosMetadata)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    private var subtaskDetail: String {
        let subtasks = draft.wrappedValue.subtasks
        guard !subtasks.isEmpty else { return "" }
        return "\(subtasks.filter(\.isCompleted).count)/\(subtasks.count)"
    }

    private var subtaskList: some View {
        ForEach(draft.wrappedValue.subtasks, id: \.id) { subtask in
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    mutate { $0.toggleSubtask(id: subtask.id) }
                } label: {
                    SymbolImage(
                        name: subtask.isCompleted ? "checkmark.circle.fill" : "circle",
                        size: Theme.Size.checkbox)
                    .foregroundStyle(
                        subtask.isCompleted ? Color.accentColor : Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    subtask.isCompleted
                        ? String(localized: "Mark \(subtask.title) incomplete")
                        : String(localized: "Mark \(subtask.title) complete"))
                TextField(String(localized: "Subtask"), text: subtaskTitle(subtask.id))
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.todosBody)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button {
                    mutate { $0.removeSubtask(id: subtask.id) }
                } label: {
                    SymbolImage(name: "xmark", size: Theme.Size.checkbox)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Remove \(subtask.title)"))
                .help(String(localized: "Remove \(subtask.title)"))
            }
            .frame(height: Theme.Size.barButtonHeight)
        }
    }

    private var addSubtaskRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: addSubtask) {
                SymbolImage(name: "plus", size: Theme.Size.checkbox)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(String(localized: "Add Subtask"))
            TextField(String(localized: "Add Subtask"), text: $newSubtaskTitle)
                .textFieldStyle(.plain)
                .font(Theme.Typography.todosBody)
                .onSubmit(addSubtask)
        }
        .frame(height: Theme.Size.barButtonHeight)
    }

    @ViewBuilder
    private var errorText: some View {
        if let errorMessage = todos.errorMessage {
            Text(errorMessage)
                .font(Theme.Typography.todosDetail)
                .foregroundStyle(Theme.Colors.destructive)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xxxl)
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            TodoStatusCaption()
            Spacer(minLength: Theme.Spacing.md)
            Button(String(localized: "Cancel"), action: todos.cancelEditing)
                .buttonStyle(TodoActionButtonStyle())
            Button(saveTitle, action: save)
                .buttonStyle(TodoActionButtonStyle(isPrimary: true))
                .disabled(!draft.wrappedValue.canSave || todos.pendingCount > 0)
                .accessibilityIdentifier("todo-save")
        }
        .padding(.horizontal, Theme.Spacing.xxxl)
        .frame(height: Theme.Size.bottomBarHeight)
    }

    private var saveTitle: String {
        draft.wrappedValue.isNew
            ? String(localized: "Create Todo")
            : String(localized: "Save Changes")
    }

    private var sections: [TodoBridgeBoardSection] {
        (todos.snapshot?.boardSections ?? []).filter { !$0.isInbox }
    }

    /// Planote stores the inbox as an id; the picker and the wire both spell it as nil.
    private var sectionSelection: Binding<UUID?> {
        Binding(
            get: {
                let id = draft.wrappedValue.boardSectionID
                guard let id else { return nil }
                guard let section = todos.snapshot?.boardSections.first(where: { $0.id == id }),
                    !section.isInbox
                else { return nil }
                return id
            },
            set: { draft.wrappedValue.boardSectionID = $0 })
    }

    private var labels: [TodoBridgeLabel] {
        todos.snapshot?.labels ?? []
    }

    private func save() {
        Task { await todos.save(draft.wrappedValue) }
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        mutate {
            $0.addSubtask()
            guard !$0.subtasks.isEmpty else { return }
            $0.subtasks[$0.subtasks.count - 1].title = title
        }
        newSubtaskTitle = ""
    }

    /// Subtask text edits every keystroke; structure goes through the draft's own helpers.
    private func mutate(_ change: (inout TodoEditorDraft) -> Void) {
        var updated = draft.wrappedValue
        change(&updated)
        draft.wrappedValue = updated
    }

    private func subtaskTitle(_ id: UUID) -> Binding<String> {
        Binding(
            get: { draft.wrappedValue.subtasks.first(where: { $0.id == id })?.title ?? "" },
            set: { title in
                guard let index = draft.wrappedValue.subtasks.firstIndex(where: { $0.id == id })
                else { return }
                draft.wrappedValue.subtasks[index].title = title
            })
    }
}
