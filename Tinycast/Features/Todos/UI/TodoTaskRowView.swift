import SwiftUI

struct TodoTaskRowView: View {
    @Environment(TodosCoordinator.self) private var coordinator
    let item: LocalTodo
    let children: [LocalTodo]
    let isSubtask: Bool
    let editingTitle: FocusState<TodosView.TitleFocus?>.Binding

    @State private var hovered = false

    private var isSelected: Bool { coordinator.selectedID == item.id }
    private var focusSnapshot: TodoFocusBridge.Snapshot? { coordinator.focusBridge?.snapshot }
    private var isActiveFocus: Bool {
        guard let snap = focusSnapshot, !snap.isIdle, snap.phaseKind == .focus else { return false }
        return snap.activeTaskID == item.id
    }
    private var showProjectBadge: Bool {
        !isSubtask && coordinator.scope != .inbox && coordinator.scope.projectName == nil
            && item.project != nil
    }

    var body: some View {
        if coordinator.editingID == item.id {
            inlineTitleEditor
        } else {
            rowBody
        }
    }

    private var rowBody: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            expandButtonSlot
            checkboxButton
            mainContent
            if hovered {
                hoverActions
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            rowFill,
            in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .opacity(item.isCompleted ? 0.60 : 1)
        .onHover { hovered = $0 }
        .onTapGesture {
            coordinator.selectedID = item.id
        }
        .contextMenu { rowContextMenu }
    }

    private var rowFill: Color {
        if isSelected { return Theme.Colors.selection }
        return hovered ? Theme.Colors.rowHover : Color.clear
    }

    @ViewBuilder
    private var expandButtonSlot: some View {
        if !isSubtask {
            if children.isEmpty {
                Color.clear.frame(width: 14, height: 18)
            } else {
                Button {
                    if !coordinator.expanded.insert(item.id).inserted {
                        coordinator.expanded.remove(item.id)
                    }
                } label: {
                    Image(
                        systemName: coordinator.expanded.contains(item.id)
                            ? "chevron.down" : "chevron.right"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 14, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Subtasks")
            }
        }
    }

    private var checkboxButton: some View {
        Button {
            coordinator.toggle(item)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        item.isCompleted
                            ? Theme.Colors.success : item.effectivePriority.tint,
                        lineWidth: 1.6)
                    .background(
                        Circle().fill(item.isCompleted ? Theme.Colors.success : Color.clear))
                    .frame(width: 17, height: 17)
                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Colors.composerSendInk)
                }
            }
            .frame(width: 18, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isCompleted ? "Mark incomplete" : "Mark complete")
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                if isActiveFocus {
                    Circle()
                        .fill(Theme.Colors.brand)
                        .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
                }
                Text(verbatim: item.title)
                    .font(.body)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(
                        item.isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isActiveFocus, let snap = focusSnapshot {
                    Text(verbatim: snap.remainingText)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.Colors.brand)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Colors.controlSurface, in: Capsule())
                }
            }
            if hasMetadata {
                metadataRow
            }
        }
    }

    private var hasMetadata: Bool {
        let hasReminder = !item.isCompleted && item.reminder != nil
        let hasPomos = !isSubtask
            && (item.effectiveEstimatedPomodoros > 0 || item.effectiveCompletedPomodoros > 0)
        let hasHighPriority = !item.isCompleted && item.effectivePriority == .high
        let hasNotes = !(item.notes ?? "").isEmpty
        return hasReminder || hasPomos || hasHighPriority || showProjectBadge || hasNotes
            || !children.isEmpty
    }

    private var metadataRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let date = item.reminder, !item.isCompleted {
                let overdue = TodoListFilter.isOverdueReminder(item, now: .now)
                Label(
                    date.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "bell"
                )
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(overdue ? Theme.Colors.destructive : Theme.Colors.textSecondary)
            }
            if !isSubtask,
               item.effectiveEstimatedPomodoros > 0 || item.effectiveCompletedPomodoros > 0
            {
                let done = item.effectiveCompletedPomodoros
                let est = item.effectiveEstimatedPomodoros
                let label = est > 0 ? "\(done)/\(est)" : "\(done)"
                let mins = item.effectiveFocusedMinutes
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "timer")
                    Text(verbatim: mins > 0 ? "\(label) · \(mins)m" : label)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(isActiveFocus ? Theme.Colors.brand : Theme.Colors.textSecondary)
            }
            if !item.isCompleted, item.effectivePriority == .high {
                Label("High", systemImage: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.destructive)
            }
            if showProjectBadge, let projectName = item.project {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Color(todoProjectHex: coordinator.projectColorHex(for: projectName)))
                        .frame(width: 6, height: 6)
                    Text(verbatim: projectName)
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 1)
                .background(Theme.Colors.controlSurface, in: Capsule())
            }
            if let notes = item.notes, !notes.isEmpty {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .help(notes)
            }
            if !children.isEmpty {
                let done = children.filter(\.isCompleted).count
                Text(verbatim: "\(done)/\(children.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(
                        done == children.count ? Theme.Colors.success : Theme.Colors.textTertiary)
            }
        }
    }

    private var hoverActions: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if !isSubtask, !item.isCompleted, let bridge = coordinator.focusBridge,
               bridge.snapshot.isEnabled
            {
                Button("Focus", systemImage: "timer") {
                    bridge.focusTask(id: item.id, title: item.title)
                }
                .help("Focus on this task")
                .foregroundStyle(isActiveFocus ? Theme.Colors.brand : Theme.Colors.textSecondary)
            }
            if !isSubtask {
                Button("Add subtask", systemImage: "plus") {
                    coordinator.startInlineSubtask(for: item)
                }
                .help("Add subtask")
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            Button("Edit", systemImage: "pencil") {
                coordinator.edit(item)
            }
            .help("Edit")
            .foregroundStyle(Theme.Colors.textSecondary)
            Menu {
                rowContextMenu
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Actions")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var rowContextMenu: some View {
        if !isSubtask, !item.isCompleted, let bridge = coordinator.focusBridge,
           bridge.snapshot.isEnabled
        {
            Button("Start Focus", systemImage: "timer") {
                bridge.focusTask(id: item.id, title: item.title)
            }
        }
        Button(item.isCompleted ? "Mark incomplete" : "Mark complete") {
            coordinator.toggle(item)
        }
        if !isSubtask {
            Button("Add subtask") {
                coordinator.startInlineSubtask(for: item)
            }
            Menu("Move to project") {
                if item.project != nil {
                    Button("Inbox") { coordinator.move(item, to: nil) }
                }
                ForEach(coordinator.board.projects.filter { $0 != item.project }, id: \.self) {
                    name in
                    Button(name) { coordinator.move(item, to: name) }
                }
            }
            .disabled(coordinator.board.projects.isEmpty)
        }
        Button("Edit") {
            coordinator.edit(item)
        }
        Divider()
        Button("Delete", role: .destructive) {
            coordinator.delete(item)
        }
    }

    private var inlineTitleEditor: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Theme.Spacing.md) {
            TextField("Task title", text: $coordinator.draft)
                .focused(editingTitle, equals: .row(item.id))
                .onSubmit(coordinator.submit)
                .onExitCommand(perform: coordinator.cancelEditing)
            Toggle("Time reminder", systemImage: "bell", isOn: $coordinator.reminderEnabled)
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Time reminder")
            if coordinator.reminderEnabled {
                DatePicker(
                    "Time reminder", selection: $coordinator.reminderDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            Button("Cancel", systemImage: "xmark", action: coordinator.cancelEditing)
                .labelStyle(.iconOnly)
            Button("Save", systemImage: "checkmark", action: coordinator.submit)
                .labelStyle(.iconOnly)
                .disabled(coordinator.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Theme.Colors.selection,
            in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .onAppear { editingTitle.wrappedValue = .row(item.id) }
    }
}
