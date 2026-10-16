import SwiftUI

struct ShellCommandScreen: PaletteScreen {
    let coordinator: CustomCommandCoordinator
    let vm: PaletteState
    let openActions: () -> Void
    let scrollToFollow: () -> Void
    let rows: [ShellCommandHistory.Row]
    let landingSelection: Int

    init(
        query: ShellCommandQuery, coordinator: CustomCommandCoordinator,
        vm: PaletteState, openActions: @escaping () -> Void, scrollToFollow: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.vm = vm
        self.openActions = openActions
        self.scrollToFollow = scrollToFollow
        rows = coordinator.shellHistoryRows(for: query)
        landingSelection = rows.firstIndex { $0.command == query.command } ?? 0
    }

    var primaryActionTitle: String { String(localized: "Run Command") }

    private func row(at selection: Int) -> ShellCommandHistory.Row? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let row = row(at: selection) else { return nil }
        var items = [
            PopoverMenuItem(
                title: String(localized: "Run Command"), systemImage: "terminal", shortcut: "↵"
            ) { coordinator.runShellCommand(row.command) },
            PopoverMenuItem(
                title: String(localized: "Edit Command"), systemImage: "pencil", shortcut: "⌘↵"
            ) { coordinator.editShellCommand(row.command) }
        ]
        if case .history = row {
            items += [
                PopoverMenuItem(
                    title: row.isPinned ? String(localized: "Unpin Command") : String(localized: "Pin Command"),
                    systemImage: row.isPinned ? "pin.slash" : "pin", startsSection: true, shortcut: "⌘."
                ) { coordinator.togglePinnedShellHistoryCommand(row.command) },
                PopoverMenuItem(title: String(localized: "Move to Top"), systemImage: "arrow.up.to.line") {
                    coordinator.moveShellHistoryCommandToTop(row.command)
                },
                PopoverMenuItem(
                    title: String(localized: "Delete Entry"), systemImage: "trash", startsSection: true,
                    shortcut: "⌃X", isDestructive: true
                ) { coordinator.deleteShellHistoryCommand(row.command) }
            ]
        }
        return PopoverMenuContent(header: row.command, items: items)
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        coordinator.runShellCommand(row.command)
    }

    func secondary(at selection: Int) -> Bool {
        guard let row = row(at: selection) else { return false }
        coordinator.editShellCommand(row.command)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard let row = row(at: selection), case .history = row else { return false }
        switch shortcut {
        case .pin: coordinator.togglePinnedShellHistoryCommand(row.command)
        case .delete: coordinator.deleteShellHistoryCommand(row.command)
        default: return false
        }
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        guard !rows.isEmpty else {
            return AnyView(EmptyResults(text: String(localized: "No shell commands yet")))
        }
        return AnyView(ShellCommandList(
            rows: rows, selectedID: row(at: selection)?.id, scroll: scroll,
            onSelect: { row in
                if let index = rows.firstIndex(of: row) { vm.selection = index }
            },
            onActivate: { activate(at: vm.selection) },
            onActions: { row in
                if let index = rows.firstIndex(of: row) { vm.selection = index }
                openActions()
            })
            .onChange(of: vm.followToken) { scrollToFollow() })
    }
}
