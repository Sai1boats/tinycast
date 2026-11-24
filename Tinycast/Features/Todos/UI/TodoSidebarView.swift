import SwiftUI

struct TodoSidebarView: View {
    @Environment(TodosCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            smartViewsSection
            Divider()
            projectsSection
            if let snapshot = coordinator.focusBridge?.snapshot, snapshot.isEnabled {
                focusDock(snapshot)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.cardFill)
    }

    private var smartViewsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            smartButton(.inbox, title: String(localized: "Inbox"), symbol: "tray", tint: Theme.Colors.brand)
            smartButton(.today, title: String(localized: "Today"), symbol: "sun.max", tint: Theme.Colors.warning)
            smartButton(
                .scheduled, title: String(localized: "Scheduled"), symbol: "calendar",
                tint: Theme.Colors.destructive)
            smartButton(.all, title: String(localized: "All"), symbol: "square.stack.3d.up", tint: Theme.Colors.success)
        }
    }

    private func smartButton(
        _ scope: TodoViewScope,
        title: String,
        symbol: String,
        tint: Color
    ) -> some View {
        let active = coordinator.scope == scope
        let count = TodoListFilter.openCount(
            for: scope, in: coordinator.items, now: .now, calendar: .current)
        return Button {
            coordinator.selectScope(scope)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(active ? tint : Theme.Colors.textTertiary)
                    .frame(width: 14)
                Text(verbatim: title)
                    .font(.callout.weight(active ? .medium : .regular))
                    .foregroundStyle(active ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.xs)
                if count > 0 {
                    Text(verbatim: "\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                active ? Theme.Colors.selection : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Projects")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Button("New project", systemImage: "plus", action: coordinator.addProject)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .help("New project")
                    .disabled(!coordinator.loaded)
            }
            .padding(.horizontal, Theme.Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    ForEach(coordinator.board.projects, id: \.self) { projectRow($0) }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func projectRow(_ name: String) -> some View {
        let active = coordinator.scope == .project(name)
        let count = TodoListFilter.openCount(
            for: .project(name), in: coordinator.items, now: .now, calendar: .current)
        let color = Color(todoProjectHex: coordinator.projectColorHex(for: name))
        return Button {
            coordinator.selectScope(.project(name))
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(color)
                    .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
                Text(verbatim: name)
                    .font(.callout.weight(active ? .medium : .regular))
                    .foregroundStyle(active ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.xs)
                if count > 0 {
                    Text(verbatim: "\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                active ? Theme.Colors.selection : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") { coordinator.renameProject(name) }
            Button("Delete", role: .destructive) { coordinator.deleteProject(name) }
        }
    }

    private func focusDock(_ snapshot: TodoFocusBridge.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if snapshot.isIdle {
                HStack {
                    Label("Focus", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Text(verbatim: "\(snapshot.todayCount) · \(snapshot.todayMinutes)m")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Button {
                    coordinator.focusBridge?.focusTask(id: nil, title: "")
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text("Start Focus")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.Colors.composerSendInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        Theme.Colors.composerSend,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                activeFocusDock(snapshot)
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

    private func activeFocusDock(_ snapshot: TodoFocusBridge.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(snapshot.phaseKind.tint)
                    .frame(width: Theme.Size.colorDot, height: Theme.Size.colorDot)
                Text(verbatim: snapshot.phaseTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.xs)
                Button {
                    coordinator.focusBridge?.toggleWidget()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption)
                        .foregroundStyle(
                            snapshot.isWidgetVisible
                                ? snapshot.phaseKind.tint : Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help(snapshot.isWidgetVisible ? "Hide floating timer" : "Show floating timer")
            }

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: snapshot.remainingText)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(verbatim: "\(snapshot.todayCount) · \(snapshot.todayMinutes)m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            focusTaskBindingRow(snapshot)

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    coordinator.focusBridge?.toggleRunning()
                } label: {
                    Text(snapshot.isRunning ? "Pause" : "Resume")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            Theme.Colors.controlSurface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    coordinator.focusBridge?.skip()
                } label: {
                    Text("Skip")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(height: 26)
                        .background(
                            Theme.Colors.rowHover,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.separator)
                    Capsule()
                        .fill(snapshot.phaseKind.tint)
                        .frame(width: max(4, proxy.size.width * snapshot.progress))
                }
            }
            .frame(height: 2.5)
        }
    }

    @ViewBuilder
    private func focusTaskBindingRow(_ snapshot: TodoFocusBridge.Snapshot) -> some View {
        if let activeID = snapshot.activeTaskID {
            let label = snapshot.activeTaskTitle.isEmpty
                ? String(localized: "Focused task") : snapshot.activeTaskTitle
            HStack(spacing: Theme.Spacing.xs) {
                Button {
                    coordinator.revealTask(id: activeID)
                } label: {
                    Text(verbatim: label)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Reveal bound task")

                Button {
                    coordinator.focusBridge?.unbindTask()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Unbind task (Free Focus)")
                .accessibilityLabel("Unbind task")
            }
        } else {
            Text(
                snapshot.activeTaskTitle.isEmpty
                    ? String(localized: "Free Focus") : snapshot.activeTaskTitle
            )
            .font(.caption)
            .foregroundStyle(Theme.Colors.textTertiary)
            .lineLimit(1)
        }
    }
}
