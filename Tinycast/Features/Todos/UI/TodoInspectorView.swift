import SwiftUI

struct TodoInspectorView: View {
    @Environment(TodosCoordinator.self) private var coordinator
    @State private var titleDraft = ""
    @State private var notesDraft = ""
    @State private var newSubtaskDraft = ""
    @State private var customReminderDate = Date.now.addingTimeInterval(3600)

    private var selectedItem: LocalTodo? {
        guard let id = coordinator.selectedID else { return nil }
        return coordinator.items.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let item = selectedItem {
                inspectorContent(for: item)
            } else {
                emptyInspector
            }
        }
        .frame(width: Theme.Size.todoInspector)
        .frame(maxHeight: .infinity)
        .background(Theme.Colors.cardFill)
        .onChange(of: coordinator.selectedID, initial: true) { _, _ in
            syncDrafts()
        }
        .onChange(of: selectedItem) { _, _ in
            syncDrafts()
        }
    }

    private var emptyInspector: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sidebar.right")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No task selected")
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Select a task to edit notes, priority, pomodoro estimates, or reminders.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inspectorContent(for item: LocalTodo) -> some View {
        let isRoot = item.parentID == nil
        let subtasks = isRoot ? coordinator.items.filter { $0.parentID == item.id } : []
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    headerSection(item, isRoot: isRoot)
                    if isRoot, let bridge = coordinator.focusBridge, bridge.snapshot.isEnabled {
                        pomodoroCard(item, bridge: bridge)
                    }
                    notesSection(item)
                    prioritySection(item)
                    reminderSection(item)
                    if isRoot {
                        projectSection(item)
                        subtasksSection(item, subtasks: subtasks)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            Divider()
            HStack {
                Text("Saved locally")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    coordinator.delete(item)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.Colors.destructive)
                .font(.caption.weight(.medium))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func headerSection(_ item: LocalTodo, isRoot: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(isRoot ? "Task Details" : "Subtask Details")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Button {
                    coordinator.toggle(item)
                } label: {
                    Text(item.isCompleted ? "Completed" : "Mark Complete")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            item.isCompleted ? Theme.Colors.success : Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xxs + 1)
                        .background(
                            Theme.Colors.controlSurface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            TextField("Task title", text: $titleDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .onSubmit { commitTitle(for: item) }
                .onChange(of: titleDraft) { _, newValue in
                    if newValue.contains("\n") {
                        titleDraft = newValue.replacingOccurrences(of: "\n", with: " ")
                        commitTitle(for: item)
                    }
                }
        }
    }

    private func pomodoroCard(_ item: LocalTodo, bridge: TodoFocusBridge) -> some View {
        let snap = bridge.snapshot
        let isFocused = snap.activeTaskID == item.id && snap.phaseKind == .focus && !snap.isIdle
        let est = item.effectiveEstimatedPomodoros
        let done = item.effectiveCompletedPomodoros
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Pomodoro", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(verbatim: "\(done) done · \(item.effectiveFocusedMinutes)m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            HStack {
                Text("Estimated")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        coordinator.updateTask(item.id, estimatedPomodoros: max(0, est - 1))
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption2.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(
                                Theme.Colors.controlSurface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text(verbatim: "\(est)")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .frame(minWidth: 16)

                    Button {
                        coordinator.updateTask(item.id, estimatedPomodoros: min(8, est + 1))
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(
                                Theme.Colors.controlSurface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                if isFocused {
                    bridge.toggleRunning()
                } else {
                    bridge.focusTask(id: item.id, title: item.title)
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: isFocused && snap.isRunning ? "pause.fill" : "play.fill")
                        .font(.caption2)
                    Text(
                        isFocused
                            ? (snap.isRunning ? "Focusing · Pause" : "Paused · Resume")
                            : "Focus This Task"
                    )
                    .font(.caption.weight(.semibold))
                }
                .foregroundStyle(
                    isFocused ? Theme.Colors.brand : Theme.Colors.composerSendInk)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    isFocused ? Theme.Colors.controlHover : Theme.Colors.composerSend,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(item.isCompleted)
            .opacity(item.isCompleted ? 0.45 : 1)
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

    private func notesSection(_ item: LocalTodo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Notes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                if notesDraft != (item.notes ?? "") {
                    Button("Save") {
                        coordinator.updateTask(item.id, notes: notesDraft)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.medium))
                }
            }
            TextEditor(text: $notesDraft)
                .font(.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 74, maxHeight: 140)
                .padding(Theme.Spacing.md)
                .background(
                    Theme.Colors.utilityEditor,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.cardStroke, lineWidth: Theme.Size.hairline)
                }
                .onChange(of: notesDraft) { _, _ in
                    // Keep commit explicit on Save or selection switch to avoid spamming disk writes.
                }
        }
        .onDisappear {
            if notesDraft != (item.notes ?? "") {
                coordinator.updateTask(item.id, notes: notesDraft)
            }
        }
    }

    private func prioritySection(_ item: LocalTodo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Priority")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textTertiary)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(TodoPriority.allCases, id: \.self) { level in
                    let active = item.effectivePriority == level
                    Button {
                        coordinator.updateTask(item.id, priority: level)
                    } label: {
                        Text(verbatim: level.title)
                            .font(.caption.weight(active ? .semibold : .regular))
                            .foregroundStyle(active ? level.tint : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(
                                active ? Theme.Colors.selection : Theme.Colors.controlSurface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reminderSection(_ item: LocalTodo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Reminder")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                if let date = item.reminder {
                    let overdue = TodoListFilter.isOverdueReminder(item, now: .now)
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(overdue ? Theme.Colors.destructive : Theme.Colors.brand)
                } else {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(TodoReminderPreset.allCases, id: \.self) { preset in
                    Button {
                        let date = preset.date(from: .now, calendar: .current)
                        coordinator.updateTask(item.id, reminder: .some(date))
                    } label: {
                        Text(verbatim: preset.title)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                Theme.Colors.controlSurface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                DatePicker(
                    "Custom reminder",
                    selection: $customReminderDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Button("Apply") {
                    coordinator.updateTask(item.id, reminder: .some(customReminderDate))
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
                Spacer()
                if item.reminder != nil {
                    Button("Clear") {
                        coordinator.updateTask(item.id, reminder: .some(nil))
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.destructive)
                }
            }
        }
    }

    private func projectSection(_ item: LocalTodo) -> some View {
        HStack {
            Text("Project")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
            Picker(
                "Project",
                selection: Binding(
                    get: { item.project },
                    set: { coordinator.move(item, to: $0) }
                )
            ) {
                Text("Inbox").tag(String?.none)
                ForEach(coordinator.board.projects, id: \.self) { name in
                    Text(verbatim: name).tag(Optional(name))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 160)
        }
    }

    private func subtasksSection(_ item: LocalTodo, subtasks: [LocalTodo]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            let done = subtasks.filter(\.isCompleted).count
            Text(verbatim: subtasks.isEmpty
                ? String(localized: "Subtasks")
                : "\(String(localized: "Subtasks")) (\(done)/\(subtasks.count))")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            ForEach(subtasks) { child in
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        coordinator.toggle(child)
                    } label: {
                        Image(systemName: child.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                child.isCompleted ? Theme.Colors.success : Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    Text(verbatim: child.title)
                        .font(.callout)
                        .strikethrough(child.isCompleted)
                        .foregroundStyle(
                            child.isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        coordinator.delete(child)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                TextField("Add subtask…", text: $newSubtaskDraft)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit {
                        let trimmed = newSubtaskDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        coordinator.startInlineSubtask(for: item)
                        coordinator.inlineSubtaskDraft = trimmed
                        coordinator.submitInlineSubtask()
                        coordinator.cancelInlineSubtask()
                        newSubtaskDraft = ""
                    }
            }
        }
    }

    private func syncDrafts() {
        if let item = selectedItem {
            titleDraft = item.title
            notesDraft = item.notes ?? ""
            customReminderDate = item.reminder ?? Date.now.addingTimeInterval(3600)
        } else {
            titleDraft = ""
            notesDraft = ""
        }
    }

    private func commitTitle(for item: LocalTodo) {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.title else {
            titleDraft = item.title
            return
        }
        coordinator.updateTask(item.id, title: trimmed)
    }
}
