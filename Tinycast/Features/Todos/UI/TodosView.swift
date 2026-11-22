import SwiftUI

struct TodosView: View {
    @Environment(TodosCoordinator.self) private var coordinator
    private enum TitleFocus: Hashable { case composer, row(UUID) }
    @FocusState private var editingTitle: TitleFocus?

    private var roots: [LocalTodo] {
        coordinator.items.filter { $0.project == coordinator.project && $0.parentID == nil }
    }
    private var projectTitle: String { coordinator.project ?? String(localized: "Inbox") }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Local Todos", systemImage: "checklist").font(Theme.Typography.utilityTitle)
                Spacer()
                Button("Close", systemImage: "xmark", action: coordinator.close)
                    .labelStyle(.iconOnly).buttonStyle(UtilityCloseButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.xxl).padding(.vertical, Theme.Spacing.xl)
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: Theme.Size.todoSidebar)
                Divider()
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    HStack {
                        Text(verbatim: projectTitle).font(.largeTitle.bold())
                        Spacer()
                        if let project = coordinator.project {
                            Button("Delete", systemImage: "trash") { coordinator.deleteProject(project) }
                                .labelStyle(.iconOnly).buttonStyle(.borderless)
                        }
                    }
                    let finished = roots.filter(\.isCompleted).count
                    if !roots.isEmpty {
                        HStack {
                            ProgressView(value: Double(finished), total: Double(roots.count)).tint(.mint)
                            Text(verbatim: "\(finished) / \(roots.count)").monospacedDigit().foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                    if let error = coordinator.errorMessage {
                        HStack {
                            Text(verbatim: error)
                            if coordinator.canRetry { Button("Retry", action: coordinator.retry) }
                        }
                    }
                    ZStack {
                        if !coordinator.loaded {
                            if coordinator.pending != nil { ProgressView() }
                        } else if roots.isEmpty {
                            ContentUnavailableView("No tasks yet", systemImage: "checklist")
                        } else {
                            ScrollViewReader { scroll in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                        ForEach(roots) { task in taskGroup(task) }
                                    }
                                }
                                .onChange(of: coordinator.editingID, initial: true) { _, id in
                                    if let id { scroll.scrollTo(id) }
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    editor
                }.padding(Theme.Spacing.xxl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .disabled(coordinator.pending != nil)
        }
        .background(Theme.Colors.utilitySurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.utilityWindow))
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack {
                Text("Projects").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Button("New project", systemImage: "plus", action: coordinator.addProject)
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                    .help("New project").disabled(!coordinator.loaded)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    projectButton(nil)
                    ForEach(coordinator.board.projects, id: \.self) { projectButton($0) }
                }
            }
        }.padding(Theme.Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.controlSurface)
    }

    private func projectButton(_ name: String?) -> some View {
        Button { coordinator.select(name) } label: {
            HStack {
                Image(systemName: name == nil ? "tray" : "folder")
                Text(verbatim: name ?? String(localized: "Inbox")).lineLimit(1)
                Spacer()
            }.padding(Theme.Spacing.md)
            .background(coordinator.project == name ? Color.mint.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.barControl))
        }.buttonStyle(.plain)
        .contextMenu {
            if let name {
                Button("Rename") { coordinator.renameProject(name) }
                Button("Delete", role: .destructive) { coordinator.deleteProject(name) }
            }
        }
    }

    private func taskGroup(_ item: LocalTodo) -> some View {
        let children = coordinator.items.filter { $0.parentID == item.id }
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                if !children.isEmpty {
                    Button {
                        if !coordinator.expanded.insert(item.id).inserted { coordinator.expanded.remove(item.id) }
                    } label: {
                        Image(systemName: coordinator.expanded.contains(item.id) ? "chevron.down" : "chevron.right")
                    }.accessibilityLabel("Subtasks").buttonStyle(.plain)
                }
                row(item).id(item.id)
                if !children.isEmpty {
                    Text(verbatim: "\(children.filter(\.isCompleted).count)/\(children.count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if coordinator.expanded.contains(item.id) {
                ForEach(children) { row($0).id($0.id).padding(.leading, Theme.Spacing.xxxl) }
            }
            Divider()
        }
    }

    @ViewBuilder private func row(_ item: LocalTodo) -> some View {
        if coordinator.editingID == item.id {
            inlineEditor(for: item.id)
        } else {
            taskRow(item)
        }
    }

    private func taskRow(_ item: LocalTodo) -> some View {
        HStack {
            Toggle(isOn: Binding(get: { item.isCompleted }, set: { _ in coordinator.toggle(item) })) {
                Text(verbatim: item.title).strikethrough(item.isCompleted)
            }.toggleStyle(.checkbox)
            Spacer()
            if let date = item.reminder, !item.isCompleted {
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "bell")
                    .labelStyle(.titleAndIcon).font(.caption).foregroundStyle(.secondary)
            }
            if item.parentID == nil {
                Button("Add subtask", systemImage: "plus") { coordinator.addChild(to: item); editingTitle = .composer }
                    .help("Add subtask")
            }
            Button("Edit", systemImage: "pencil") { coordinator.edit(item) }.help("Edit")
            Menu {
                if item.parentID == nil {
                    Menu("Move to project") {
                        if item.project != nil { Button("Inbox") { coordinator.move(item, to: nil) } }
                        ForEach(coordinator.board.projects.filter { $0 != item.project }, id: \.self) { name in
                            Button(name) { coordinator.move(item, to: name) }
                        }
                    }.disabled(coordinator.board.projects.isEmpty)
                }
                Button("Delete", role: .destructive) { coordinator.delete(item) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions")
        }.labelStyle(.iconOnly).buttonStyle(.borderless)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func inlineEditor(for id: UUID) -> some View {
        @Bindable var coordinator = coordinator
        return HStack {
            TextField("Task title", text: $coordinator.draft)
                .focused($editingTitle, equals: .row(id))
                .onSubmit(coordinator.submit)
                .onExitCommand(perform: coordinator.cancelEditing)
            reminderControls
            Button("Cancel", systemImage: "xmark", action: coordinator.cancelEditing).labelStyle(.iconOnly)
            Button("Save", systemImage: "checkmark", action: coordinator.submit)
                .labelStyle(.iconOnly).disabled(emptyTitle)
        }
        .onAppear { editingTitle = .row(id) }
    }

    private var editor: some View {
        @Bindable var coordinator = coordinator
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if coordinator.editingID == nil, let parent = coordinator.items.first(where: { $0.id == coordinator.parentID }) {
                Label(parent.title, systemImage: "arrow.turn.down.right").font(.caption)
            }
            HStack {
                if coordinator.editingID == nil {
                    TextField("Task title", text: $coordinator.draft)
                        .focused($editingTitle, equals: .composer).onSubmit(coordinator.submit)
                    reminderControls
                    if coordinator.parentID != nil { Button("Cancel", action: coordinator.cancelEditing) }
                } else {
                    TextField("Task title", text: .constant(coordinator.composerTitle))
                }
                Button("Add", systemImage: "plus", action: coordinator.submit)
                    .labelStyle(.iconOnly).help("Add").disabled(emptyTitle)
            }
        }.disabled(!coordinator.loaded || coordinator.editingID != nil)
    }

    private var reminderControls: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.sm) {
            Toggle("Time reminder", systemImage: "bell", isOn: $coordinator.reminderEnabled)
                .toggleStyle(.button).labelStyle(.iconOnly).help("Time reminder")
            if coordinator.reminderEnabled {
                DatePicker("Time reminder", selection: $coordinator.reminderDate,
                           displayedComponents: [.date, .hourAndMinute]).labelsHidden().datePickerStyle(.compact)
            }
        }
    }

    private var emptyTitle: Bool { coordinator.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
