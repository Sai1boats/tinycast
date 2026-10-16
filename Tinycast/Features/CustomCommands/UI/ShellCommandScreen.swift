import SwiftUI

struct ShellCommandScreen: PaletteScreen {
    enum Row: Equatable, Identifiable {
        case completion(ShellCompletion.Candidate)
        case command(ShellCommandHistory.Row)

        var id: String {
            switch self {
            case .completion(let candidate): "shell-completion-" + candidate.id
            case .command(let row): row.id
            }
        }
    }

    let coordinator: CustomCommandCoordinator
    let vm: PaletteState
    let openActions: () -> Void
    let scrollToFollow: () -> Void
    let query: ShellCommandQuery
    let rows: [Row]
    let landingSelection: Int
    private let completionCount: Int

    init(
        query: ShellCommandQuery, coordinator: CustomCommandCoordinator,
        vm: PaletteState, openActions: @escaping () -> Void, scrollToFollow: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.vm = vm
        self.openActions = openActions
        self.scrollToFollow = scrollToFollow
        self.query = query
        let completions = coordinator.shellCompletions(for: "# " + query.input).map(Row.completion)
        let commands = coordinator.shellHistoryRows(for: query)
        rows = completions + commands.map(Row.command)
        completionCount = completions.count
        landingSelection = completions.isEmpty ? commands.firstIndex { $0.command == query.command } ?? 0 : 0
    }

    var primaryActionTitle: String {
        switch row(at: vm.selection) {
        case .completion: String(localized: "Insert Completion")
        case .command(let row) where ShellBuiltin(row.command) != nil: String(localized: "Change Directory")
        default: String(localized: "Run Command")
        }
    }

    private func row(at selection: Int) -> Row? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }

    private func command(at selection: Int) -> ShellCommandHistory.Row? {
        guard case .command(let row) = row(at: selection) else { return nil }
        return row
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let row = command(at: selection) else { return nil }
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
        items.append(PopoverMenuItem(
            title: String(localized: "Use Finder’s Folder"), systemImage: "folder", startsSection: true
        ) { coordinator.useFinderFolder() })
        return PopoverMenuContent(header: row.command, items: items)
    }

    func activate(at selection: Int) {
        switch row(at: selection) {
        case .completion(let candidate): coordinator.applyShellCompletion(candidate)
        case .command(let row): coordinator.runShellCommand(row.command)
        case nil: break
        }
    }

    func secondary(at selection: Int) -> Bool {
        guard let row = command(at: selection) else { return false }
        coordinator.editShellCommand(row.command)
        return true
    }

    /// ⇥ walks a visible completion list, takes a highlighted history line, and otherwise completes.
    func tab(at selection: Int, backwards: Bool) -> Bool {
        if completionCount > 0 {
            let current = selection < completionCount ? selection : (backwards ? 0 : -1)
            vm.selection = (current + (backwards ? -1 : 1) + completionCount) % completionCount
            vm.followToken = UUID()
            return true
        }
        if case .history(let command, _)? = command(at: selection), command != query.command {
            coordinator.editShellCommand(command)
            return true
        }
        coordinator.completeShellCommand(query)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard let row = command(at: selection), case .history = row else { return false }
        switch shortcut {
        case .pin: coordinator.togglePinnedShellHistoryCommand(row.command)
        case .delete: coordinator.deleteShellHistoryCommand(row.command)
        default: return false
        }
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(ShellCommandList(
            rows: rows, directory: coordinator.shellDirectory, selectedID: row(at: selection)?.id, scroll: scroll,
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
