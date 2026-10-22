import SwiftUI

struct TodosView: View {
    @Environment(TodosCoordinator.self) private var todos

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if todos.isShowingEditor {
                TodoEditorView()
            } else {
                listSurface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(
            colors: [Theme.Colors.todosTintTop, Theme.Colors.todosTintBottom],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .background(TodoBackdropView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        // The band above is the title bar; AppKit must not inset the content a second time.
        .ignoresSafeArea()
    }

    /// The hosting view hides the real title bar, so this band drags the window itself.
    private var titleBar: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .overlay { TodoTitlebarDragRegion() }
            statusCapsule
        }
        .frame(height: Theme.Size.todosTitlebar)
        .overlay { title }
    }

    private var title: some View {
        Text(String(localized: "Todos"))
            .font(Theme.Typography.todosBody.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, Theme.Size.todosTitleInset)
            .allowsHitTesting(false)
    }

    private var statusCapsule: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Circle()
                .fill(statusDot)
                .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
                .padding(.leading, Theme.Spacing.md)
                .accessibilityLabel(statusWord)
                .help(statusWord)
            BarButton(isCompact: true, action: refresh) {
                SymbolImage(name: "arrow.clockwise", size: Theme.Size.noteGlyph)
            }
            .accessibilityLabel(String(localized: "Refresh"))
            .help(String(localized: "Refresh"))
        }
        .frame(height: Theme.Size.barButtonHeight)
        .background(Capsule().fill(Theme.Colors.rowHover))
        .padding(.trailing, Theme.Spacing.md)
    }

    private var statusWord: String {
        switch todos.connection {
        case .checking: return String(localized: "Checking…")
        case .live: return String(localized: "Live")
        case .offline: return String(localized: "Offline")
        case .notInstalled: return String(localized: "Not Installed")
        case .syncing: return String(localized: "Syncing…")
        }
    }

    private var statusDot: Color {
        switch todos.connection {
        case .checking: return Theme.Colors.textTertiary
        case .live: return Theme.Colors.success
        case .offline: return Theme.Colors.warning
        case .notInstalled: return Theme.Colors.destructive
        case .syncing: return Theme.Colors.progress
        }
    }

    private var listSurface: some View {
        VStack(spacing: 0) {
            listHeading
            banner(hasRows: !visibleGroups.isEmpty)
            if todos.isLoading && visibleGroups.isEmpty {
                loadingState
            } else if let model = listModel, !visibleGroups.isEmpty {
                list(of: model, groups: visibleGroups)
            } else {
                emptyState
            }
            footer
        }
    }

    private var listHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(String(localized: "My Todos"))
                .font(Theme.Typography.todosHeading)
            Spacer(minLength: Theme.Spacing.md)
            Text(String(localized: "\(openCount) open tasks"))
                .font(Theme.Typography.todosControl)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.xxxl)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xxl)
    }

    private var openCount: Int {
        todos.snapshot?.tasks.filter { !$0.isCompleted }.count ?? 0
    }

    private var listModel: TodoListModel? {
        todos.snapshot.map(TodoListModel.init(snapshot:))
    }

    private var visibleGroups: [TodoSectionGroup] {
        guard let model = listModel else { return [] }
        return model.groups(
            includingCompleted: todos.isShowingCompleted, now: .now, calendar: .current)
    }

    private func list(of model: TodoListModel, groups: [TodoSectionGroup]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    TodoSectionHeader(
                        title: group.title ?? String(localized: "Inbox"),
                        count: group.tasks.count,
                        isFirst: group.id == groups.first?.id)
                    ForEach(group.tasks) { task in
                        TodoRowView(
                            task: task,
                            label: model.label(id: task.labelID),
                            isSyncing: todos.pendingCount > 0,
                            onToggle: { completed in
                                Task { await todos.setCompleted(task, completed) }
                            },
                            onOpen: { todos.beginEditing(task) })
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xxxl)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "Loading…"))
                .font(Theme.Typography.todosDetail)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SymbolImage(name: "checklist", size: Theme.Size.todosEmptyGlyph)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(emptyTitle)
                .font(Theme.Typography.todosBody)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(emptyCaption)
                .font(Theme.Typography.todosDetail)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: Theme.Spacing.sm) {
                capsuleAction(
                    "plus", String(localized: "New Todo"), String(localized: "New Todo"),
                    todos.createTodo)
                if showsOpenPlanote {
                    capsuleAction(
                        "arrow.up.forward.square", String(localized: "Open Planote"),
                        String(localized: "Open Planote"), todos.openPlanote)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.Spacing.xxxl)
    }

    private var emptyTitle: String {
        switch todos.connection {
        case .notInstalled: return String(localized: "Planote is not installed.")
        case .offline: return String(localized: "No cached tasks.")
        default: return String(localized: "No Todos")
        }
    }

    private var emptyCaption: String {
        switch todos.connection {
        case .notInstalled: return String(localized: "Install Planote to save and sync tasks.")
        case .offline: return String(localized: "Start Planote to load your tasks.")
        default: return String(localized: "Add a task to get started.")
        }
    }

    private var showsOpenPlanote: Bool {
        todos.isPlanoteInstalled && todos.connection == .offline
    }

    private func capsuleAction(
        _ symbol: String,
        _ label: String,
        _ help: String,
        _ perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: Theme.Spacing.xs) {
                SymbolImage(name: symbol, size: Theme.Size.utilityGlyph)
                    .accessibilityHidden(true)
                Text(label)
                    .font(Theme.Typography.todosControl)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: Theme.Size.barButtonHeight)
        .frosted(in: Capsule())
        .accessibilityLabel(label)
        .help(help)
    }

    /// Offline, missing Planote and failed commands all land here, so the list stays readable.
    @ViewBuilder
    private func banner(hasRows: Bool) -> some View {
        if let message = bannerMessage(hasRows: hasRows) {
            HStack(spacing: Theme.Spacing.md) {
                SymbolImage(name: "exclamationmark.triangle.fill", size: Theme.Size.utilityGlyph)
                    .foregroundStyle(bannerTint)
                    .accessibilityHidden(true)
                Text(message)
                    .font(Theme.Typography.todosDetail)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if todos.errorMessage != nil {
                    bannerAction("xmark", String(localized: "Dismiss"), action: todos.dismissError)
                } else {
                    bannerAction("arrow.clockwise", String(localized: "Retry"), action: refresh)
                }
                if todos.isPlanoteInstalled {
                    bannerAction(
                        "arrow.up.forward.square", String(localized: "Open Planote"),
                        action: todos.openPlanote)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Theme.Colors.cardFill,
                in: RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous)
                    .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, Theme.Spacing.xxxl)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private func bannerMessage(hasRows: Bool) -> String? {
        if let message = todos.errorMessage {
            return message
        }
        guard hasRows else { return nil }
        switch todos.connection {
        case .offline: return String(localized: "Planote is not running. Showing saved tasks.")
        case .notInstalled: return String(localized: "Planote is not installed.")
        default: return nil
        }
    }

    private var bannerTint: Color {
        todos.errorMessage == nil ? Theme.Colors.warning : Theme.Colors.destructive
    }

    private func bannerAction(
        _ symbol: String,
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        BarButton(isCompact: true, action: action) {
            SymbolImage(name: symbol, size: Theme.Size.utilityGlyph)
        }
        .accessibilityLabel(label)
        .help(label)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            TodoStatusCaption()
            Spacer(minLength: Theme.Spacing.md)
            Button(action: todos.toggleCompletedVisibility) {
                SymbolImage(
                    name: todos.isShowingCompleted ? "checkmark.circle.fill" : "checkmark.circle",
                    size: Theme.Size.utilityGlyph)
            }
            .buttonStyle(TodoActionButtonStyle(isIconOnly: true))
            .accessibilityLabel(String(localized: "Show completed tasks"))
            .accessibilityValue(todos.isShowingCompleted
                ? String(localized: "On") : String(localized: "Off"))
            .accessibilityIdentifier("todo-show-completed")
            .help(String(localized: "Show completed tasks"))
            Button(action: todos.openPlanote) {
                SymbolImage(name: "arrow.up.forward.square", size: Theme.Size.utilityGlyph)
            }
            .buttonStyle(TodoActionButtonStyle(isIconOnly: true))
            .accessibilityLabel(String(localized: "Open Planote"))
            .accessibilityIdentifier("todo-open-planote")
            .help(String(localized: "Open Planote"))
            Button(action: todos.createTodo) {
                SymbolImage(name: "plus", size: Theme.Size.utilityGlyph)
            }
            .buttonStyle(TodoActionButtonStyle(isIconOnly: true))
            .accessibilityLabel(String(localized: "New Todo"))
            .accessibilityIdentifier("todo-create")
            .help(String(localized: "New Todo"))
        }
        .padding(.horizontal, Theme.Spacing.xxxl)
        .frame(height: Theme.Size.bottomBarHeight)
    }

    private func refresh() {
        Task { await todos.refresh() }
    }
}

private struct TodoSectionHeader: View {
    let title: String
    let count: Int
    let isFirst: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.md)
            Text("\(count)")
                .font(Theme.Typography.todosDetail)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .font(Theme.Typography.todosDetail.weight(.semibold))
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.top, isFirst ? 0 : Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.sectionHeaderBottom)
    }
}

/// The band's drag surface: the only view in it that accepts a press.
private struct TodoTitlebarDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> TodoTitlebarDragView { TodoTitlebarDragView() }
    func updateNSView(_ view: TodoTitlebarDragView, context: Context) {}
}

private final class TodoTitlebarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
