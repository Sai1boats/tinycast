import SwiftUI

struct TodoRowView: View {
    let task: TodoBridgeTask
    let label: TodoBridgeLabel?
    let isSyncing: Bool
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            checkboxSlot
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text(task.title)
                        .font(Theme.Typography.todosRowTitle)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(
                            task.isCompleted ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .lineLimit(2)
                    if dueLabel != nil || label != nil || subtaskSummary.total > 0 {
                        metadata
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.title)
            .accessibilityIdentifier("todo-open-" + task.id.uuidString)
        }
        .padding(.vertical, Theme.Spacing.xl)
        .frame(minHeight: Theme.Size.todosRowMinHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(hovered ? Theme.Colors.rowHover : Color.clear))
        .onHover { hovered = $0 }
    }

    private var checkboxSlot: some View {
        Button {
            onToggle(!task.isCompleted)
        } label: {
            SymbolImage(
                name: task.isCompleted ? "checkmark.circle.fill" : "circle",
                size: Theme.Size.checkbox)
            .foregroundStyle(task.isCompleted ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
            .frame(width: Theme.Size.resultRowIcon, height: Theme.Size.resultRowIcon)
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
        .accessibilityIdentifier("todo-complete-" + task.id.uuidString)
        .accessibilityLabel(
            task.isCompleted
                ? String(localized: "Mark \(task.title) incomplete")
                : String(localized: "Mark \(task.title) complete"))
    }

    private var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            if let due = dueLabel {
                dueText(due)
            }
            if let label {
                HStack(spacing: Theme.Spacing.xs) {
                    labelDot(label)
                    Text(label.name)
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer(minLength: 0)
            if subtaskSummary.total > 0 {
                subtaskCount
            }
        }
        .font(Theme.Typography.todosMetadata)
    }

    private var dueLabel: TodoDueLabel? {
        TodoListModel.dueLabel(for: task.dueDate, now: .now, calendar: .current)
    }

    private var subtaskSummary: (completed: Int, total: Int) {
        TodoListModel.subtaskSummary(task: task)
    }

    private func dueText(_ due: TodoDueLabel) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if case .overdue = due {
                SymbolImage(name: "exclamationmark.circle.fill", size: Theme.Size.todosRowGlyph)
                    .foregroundStyle(Theme.Colors.destructive)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                    .accessibilityHidden(true)
            }
            Text(dueTitle(due))
                .font(Theme.Typography.todosMetadata)
                .foregroundStyle(dueTint(due))
                .lineLimit(1)
        }
    }

    private func dueTitle(_ due: TodoDueLabel) -> String {
        switch due {
        case .overdue: return String(localized: "Overdue")
        case .today: return String(localized: "Today")
        case .tomorrow: return String(localized: "Tomorrow")
        case .date(let date): return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func dueTint(_ due: TodoDueLabel) -> Color {
        switch due {
        case .overdue: return Theme.Colors.destructive
        case .today: return Color.accentColor
        case .tomorrow: return Theme.Colors.textPrimary
        case .date: return Theme.Colors.textSecondary
        }
    }

    private func labelDot(_ label: TodoBridgeLabel) -> some View {
        Circle()
            .fill(Color(todoHex: label.colorHex))
            .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
            .accessibilityLabel(label.name)
    }

    private var subtaskCount: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
            SymbolImage(name: "checklist", size: Theme.Size.todosRowGlyph)
                .foregroundStyle(Theme.Colors.textTertiary)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                .accessibilityHidden(true)
            Text("\(subtaskSummary.completed)/\(subtaskSummary.total)")
                .font(Theme.Typography.todosMetadata)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .accessibilityLabel(
            String(localized: "Subtasks: \(subtaskSummary.completed) of \(subtaskSummary.total)"))
    }
}

/// The label's own `#RRGGBB`; a malformed value falls back to a neutral dot.
private extension Color {
    init(todoHex: String) {
        let digits = todoHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
            self = Theme.Colors.textTertiary
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
