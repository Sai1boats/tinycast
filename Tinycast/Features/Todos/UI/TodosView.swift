import SwiftUI

struct TodosView: View {
    @Environment(TodosCoordinator.self) private var coordinator

    enum TitleFocus: Hashable {
        case composer, row(UUID), inlineSubtask(UUID), search
    }

    @FocusState private var editingTitle: TitleFocus?
    @State private var reminderPopoverOpen = false

    private var roots: [LocalTodo] {
        TodoListFilter.rootItems(
            in: coordinator.items,
            scope: coordinator.scope,
            query: coordinator.searchQuery,
            sort: coordinator.sortOrder,
            now: .now,
            calendar: .current)
    }

    private var activeRoots: [LocalTodo] { roots.filter { !$0.isCompleted } }
    private var completedRoots: [LocalTodo] { roots.filter(\.isCompleted) }

    private var scopeTitle: String {
        switch coordinator.scope {
        case .inbox: String(localized: "Inbox")
        case .today: String(localized: "Today")
        case .scheduled: String(localized: "Scheduled")
        case .all: String(localized: "All")
        case .project(let name): name
        }
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(spacing: 0) {
            windowHeader
            Divider()
            HStack(spacing: 0) {
                TodoSidebarView()
                    .frame(width: Theme.Size.todoSidebar)
                Divider()
                centerPane
                if coordinator.inspectorOpen {
                    Divider()
                    TodoInspectorView()
                }
            }
        }
        .background(Theme.Colors.utilitySurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.utilityWindow, style: .continuous))
        .ignoresSafeArea()
        .background { shortcutTriggers }
    }

    private var windowHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            Label("Local Todos", systemImage: "checklist")
                .font(Theme.Typography.utilityTitle)
            if let snap = coordinator.focusBridge?.snapshot, snap.isEnabled {
                Text(verbatim: "\(snap.todayCount) · \(snap.todayMinutes)m")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xxs + 1)
                    .background(Theme.Colors.controlSurface, in: Capsule())
            }
            Spacer()
            Button {
                coordinator.inspectorOpen.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        coordinator.inspectorOpen
                            ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 26)
                    .background(
                        coordinator.inspectorOpen
                            ? Theme.Colors.selection : Theme.Colors.controlSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector")

            Button("Close", systemImage: "xmark", action: coordinator.close)
                .labelStyle(.iconOnly)
                .buttonStyle(UtilityCloseButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.xl)
    }

    private var centerPane: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            centerHeader
            progressStrip
            banners
            listSurface
            composerCard
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var centerHeader: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.md) {
            Text(verbatim: scopeTitle)
                .font(.title.bold())
                .lineLimit(1)
            if !roots.isEmpty {
                Text(verbatim: "\(completedRoots.count)/\(roots.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer(minLength: Theme.Spacing.md)

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                TextField("Search", text: $coordinator.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($editingTitle, equals: .search)
                if !coordinator.searchQuery.isEmpty {
                    Button {
                        coordinator.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(width: 170, height: 30)
            .background(
                Theme.Colors.controlSurface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))

            Picker("Sort", selection: $coordinator.sortOrder) {
                Text("Default").tag(TodoSortOrder.manual)
                Text("Reminder").tag(TodoSortOrder.reminder)
                Text("Priority").tag(TodoSortOrder.priority)
            }
            .labelsHidden()
            .frame(width: 112)

            if let project = coordinator.project {
                Button("Delete", systemImage: "trash") { coordinator.deleteProject(project) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .help("Delete project")
            }
        }
    }

    @ViewBuilder
    private var progressStrip: some View {
        if !roots.isEmpty {
            ProgressView(value: Double(completedRoots.count), total: Double(roots.count))
                .tint(Theme.Colors.success)
                .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var banners: some View {
        if let error = coordinator.errorMessage {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Colors.warning)
                Text(verbatim: error)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if coordinator.canRetry {
                    Button("Retry", action: coordinator.retry)
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.Colors.cardFill,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }

        if let undoText = coordinator.undoBannerMessage {
            HStack(spacing: Theme.Spacing.md) {
                Text(verbatim: undoText)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward", action: coordinator.undoDelete)
                    .buttonStyle(.borderless)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
                Button("Dismiss", systemImage: "xmark", action: coordinator.dismissUndo)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Theme.Colors.controlSurface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    private var listSurface: some View {
        ZStack {
            if !coordinator.loaded {
                if coordinator.pending != nil { ProgressView() }
            } else if roots.isEmpty {
                ContentUnavailableView(
                    coordinator.searchQuery.isEmpty ? "No tasks yet" : "No matching tasks",
                    systemImage: "checklist")
            } else {
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            ForEach(activeRoots) { task in taskGroup(task) }
                            if !completedRoots.isEmpty {
                                completedSection
                            }
                        }
                    }
                    .onChange(of: coordinator.editingID, initial: true) { _, id in
                        if let id { scroll.scrollTo(id) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskGroup(_ item: LocalTodo) -> some View {
        let children = coordinator.items.filter { $0.parentID == item.id }
        let showChildren = coordinator.expanded.contains(item.id) && !children.isEmpty
        let addingInline = coordinator.inlineSubtaskParentID == item.id
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            TodoTaskRowView(
                item: item, children: children, isSubtask: false, editingTitle: $editingTitle
            )
            .id(item.id)
            if showChildren || addingInline {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if showChildren {
                        ForEach(children) { child in
                            TodoTaskRowView(
                                item: child, children: [], isSubtask: true,
                                editingTitle: $editingTitle
                            )
                            .id(child.id)
                        }
                    }
                    if addingInline {
                        inlineSubtaskComposer(for: item)
                    }
                }
                .padding(.leading, Theme.Spacing.xxl + Theme.Spacing.md)
            }
        }
    }

    private func inlineSubtaskComposer(for parent: LocalTodo) -> some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "plus")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            TextField("New subtask…", text: $coordinator.inlineSubtaskDraft)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($editingTitle, equals: .inlineSubtask(parent.id))
                .onSubmit { coordinator.submitInlineSubtask() }
                .onExitCommand { coordinator.cancelInlineSubtask() }
            Button("Cancel", action: coordinator.cancelInlineSubtask)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Theme.Colors.utilityEditor,
            in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
        }
        .onAppear { editingTitle = .inlineSubtask(parent.id) }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Button {
                coordinator.showCompletedGroup.toggle()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(
                        systemName: coordinator.showCompletedGroup
                            ? "chevron.down" : "chevron.right"
                    )
                    .font(.caption2.weight(.semibold))
                    Text(verbatim: "\(String(localized: "Completed")) (\(completedRoots.count))")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Spacing.md)

            if coordinator.showCompletedGroup {
                ForEach(completedRoots) { task in taskGroup(task) }
            }
        }
    }

    private var composerCard: some View {
        @Bindable var coordinator = coordinator
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if coordinator.editingID == nil,
               let parent = coordinator.items.first(where: { $0.id == coordinator.parentID })
            {
                HStack(spacing: Theme.Spacing.sm) {
                    Label(parent.title, systemImage: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Button("Cancel", action: coordinator.cancelEditing)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .padding(.horizontal, Theme.Spacing.xs)
            }

            if reminderPopoverOpen && coordinator.editingID == nil {
                composerReminderTray
            }

            HStack(spacing: Theme.Spacing.md) {
                if coordinator.editingID == nil {
                    TextField("Task title", text: $coordinator.draft)
                        .textFieldStyle(.plain)
                        .focused($editingTitle, equals: .composer)
                        .onSubmit(coordinator.submit)
                } else {
                    TextField("Task title", text: .constant(coordinator.composerTitle))
                        .textFieldStyle(.plain)
                }

                Button {
                    coordinator.composerPriority = coordinator.composerPriority.next
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "flag.fill")
                        if coordinator.composerPriority != .none {
                            Text(verbatim: coordinator.composerPriority.title)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(coordinator.composerPriority.tint)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 28)
                    .background(
                        Theme.Colors.controlSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Priority")

                Button {
                    reminderPopoverOpen.toggle()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "bell")
                        if coordinator.reminderEnabled {
                            Text(coordinator.reminderDate.formatted(date: .omitted, time: .shortened))
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        coordinator.reminderEnabled
                            ? Theme.Colors.brand : Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 28)
                    .background(
                        coordinator.reminderEnabled
                            ? Theme.Colors.selection : Theme.Colors.controlSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Time reminder")

                Button(action: coordinator.submit) {
                    Image(systemName: "plus")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.Colors.composerSendInk)
                        .frame(width: 28, height: 28)
                        .background(
                            Theme.Colors.composerSend,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Add")
                .disabled(emptyTitle)
                .opacity(emptyTitle ? 0.40 : 1)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.Colors.utilityEditor,
                in: RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous)
                    .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
            }
        }
        .disabled(!coordinator.loaded || coordinator.editingID != nil)
    }

    private var composerReminderTray: some View {
        @Bindable var coordinator = coordinator
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Quick Reminder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if coordinator.reminderEnabled {
                    Button("Clear reminder", role: .destructive) {
                        coordinator.reminderEnabled = false
                        reminderPopoverOpen = false
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Button("Close", systemImage: "xmark") {
                    reminderPopoverOpen = false
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.Colors.textTertiary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TodoReminderPreset.allCases, id: \.self) { preset in
                    Button {
                        coordinator.reminderDate = preset.date(from: .now, calendar: .current)
                        coordinator.reminderEnabled = true
                    } label: {
                        Text(verbatim: preset.title)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs + 1)
                            .background(
                                Theme.Colors.controlSurface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                Toggle("Custom time", isOn: $coordinator.reminderEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
                if coordinator.reminderEnabled {
                    DatePicker(
                        "Time reminder",
                        selection: $coordinator.reminderDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                Spacer()
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            Theme.Colors.utilityEditor,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
        }
    }

    private var shortcutTriggers: some View {
        Group {
            Button("") { editingTitle = .composer }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { editingTitle = .search }
                .keyboardShortcut("f", modifiers: .command)
            Button("") {
                if let selectedID = coordinator.selectedID,
                   let task = coordinator.items.first(where: {
                       $0.id == selectedID && !$0.isCompleted && $0.parentID == nil
                   })
                {
                    coordinator.focusBridge?.focusTask(id: task.id, title: task.title)
                } else {
                    coordinator.focusBridge?.toggleRunning()
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            Button("") {
                if coordinator.canUndoDelete { coordinator.undoDelete() }
            }
            .keyboardShortcut("z", modifiers: .command)
        }
        .hidden()
    }

    private var emptyTitle: Bool {
        coordinator.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
