import Foundation
import Observation
import SwiftUI
import Synchronization

@main
@MainActor
struct ShellHistoryTests {
    static var failures = 0

    static func main() {
        var history = ShellCommandHistory()
        let emptyQuery = ShellCommandQuery("# ")!
        check(history.rows(for: emptyQuery).isEmpty, "an empty prefix has no runnable blank row")
        history.record(" \n\t ")
        check(history.commands.isEmpty, "blank attempts are ignored")

        let quoted = #"printf '%s' "hello # world" | cat"#
        history.record("  " + quoted + "  ")
        history.record("git status")
        history.record("git log --oneline")
        history.record(quoted)
        check(history.commands == [quoted, "git log --oneline", "git status"],
              "repeats move to the front without changing shell syntax")
        check(history.rows(for: emptyQuery).map(\.command) == history.commands,
              "the prefix lists history in recency order")
        let search = history.rows(for: ShellCommandQuery("# GIT")!)
        check(search == [.typed("GIT"), .history("git log --oneline"), .history("git status")],
              "case-insensitive search retains the direct execution row")
        check(history.rows(for: ShellCommandQuery("# oneline git")!)
              == [.typed("oneline git"), .history("git log --oneline")],
              "every keyword must match regardless of keyword order")
        check(history.rows(for: ShellCommandQuery("# git status")!) == [.history("git status")],
              "an exact typed command appears only once")
        check(history.rows(for: ShellCommandQuery("# missing")!) == [.typed("missing")],
              "a command absent from history can still run")
        check(history.rows(for: ShellCommandQuery("#   \t ")!).map(\.command) == history.commands,
              "whitespace after the prefix lists all history")
        check(Set(search.map(\.id)).count == search.count, "typed and history rows have distinct identities")

        for index in 0..<105 { history.record("echo \(index)") }
        check(history.commands.count == 100, "history caps at 100 commands")
        check(history.commands.first == "echo 104" && history.commands.last == "echo 5",
              "the oldest commands are evicted")
        history.record("echo 5")
        check(history.commands.count == 100 && history.commands.first == "echo 5",
              "rerunning at capacity retains 100 distinct commands")
        let sanitized = ShellCommandHistory(commands: [" ", " pwd ", "pwd", "PWD"] + history.commands)
        check(sanitized.commands.count == 100 && sanitized.commands.prefix(2) == ["pwd", "PWD"],
              "loading removes blanks and exact duplicates while preserving shell case")

        testHistoryActions()
        testScreenActions()

        let suite = "shell-history-test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Could not create test defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShellCommandHistoryStore(defaults: defaults)
        store.record(quoted)
        store.record("git status")
        let changed = Mutex(false)
        withObservationTracking {
            _ = store.history.rows(for: emptyQuery)
        } onChange: {
            changed.withLock { $0 = true }
        }
        store.record(quoted)
        check(changed.withLock { $0 }, "recording invalidates the visible history")
        check(ShellCommandHistoryStore(defaults: defaults).history.commands == [quoted, "git status"],
              "history and recency survive reopening the store")
        for index in 0..<105 { store.record("echo \(index)") }
        let reopened = ShellCommandHistoryStore(defaults: defaults)
        check(reopened.history.commands == store.history.commands && reopened.history.commands.count == 100,
              "the persisted history also retains only the latest 100 commands")
        let snapshot = store.history.rows(for: emptyQuery)
        store.record("pwd")
        check(snapshot.first?.command == "echo 104", "rendered rows retain their selection snapshot")
        store.togglePinned("echo 104")
        store.togglePinned("echo 103")
        store.moveToTop("echo 103")
        store.moveToTop("echo 102")
        let savedActions = ShellCommandHistoryStore(defaults: defaults).history
        check(savedActions.pinnedCommands == ["echo 103", "echo 104"],
              "pin state and the pinned order survive reopening")
        check(savedActions.commands.prefix(3) == ["echo 103", "echo 104", "echo 102"],
              "ordinary move-to-top order survives reopening")
        store.remove("echo 103")
        let savedDeletion = ShellCommandHistoryStore(defaults: defaults).history
        check(!savedDeletion.commands.contains("echo 103") && savedDeletion.pinnedCommands == ["echo 104"],
              "deleting a pin removes both its history and pin state on disk")
        store.togglePinned("echo 104")
        check(ShellCommandHistoryStore(defaults: defaults).history.pinnedCommands.isEmpty,
              "unpinning persists")

        if failures > 0 { exit(1) }
        print("All shell history checks passed")
    }

    private static func testHistoryActions() {
        var history = ShellCommandHistory(commands: ["newest", "middle", "oldest"])
        history.togglePinned("oldest")
        history.togglePinned("middle")
        check(history.commands == ["oldest", "middle", "newest"], "pins lead in pin order")
        check(history.rows(for: ShellCommandQuery("# ")!)
              == [.history("oldest", isPinned: true), .history("middle", isPinned: true), .history("newest")],
              "rows carry their pin state")
        history.moveToTop("middle")
        check(history.commands == ["middle", "oldest", "newest"], "move to top reorders the pinned block")
        history.record("oldest")
        check(history.commands.first == "middle", "running a pin preserves its fixed position")
        history.record("fresh")
        history.moveToTop("newest")
        check(history.commands == ["middle", "oldest", "newest", "fresh"],
              "moving an ordinary row to top keeps it below the pins")
        history.togglePinned("oldest")
        check(history.commands == ["middle", "oldest", "newest", "fresh"] && history.pinnedCommands == ["middle"],
              "unpinning rejoins the newest ordinary position")
        history.remove("middle")
        check(!history.commands.contains("middle") && history.pinnedCommands.isEmpty,
              "deleting a pin removes its metadata")
        history.remove("newest")
        check(history.commands == ["oldest", "fresh"], "deleting an ordinary record preserves its neighbors")
        let unchanged = history
        history.togglePinned("absent")
        history.moveToTop("absent")
        history.remove("absent")
        check(history == unchanged, "stale menu actions never create missing commands")
        history.togglePinned("oldest")
        for index in 0..<120 { history.record("echo \(index)") }
        check(history.commands.count == 101 && history.commands.first == "oldest",
              "fixed commands survive eviction in addition to the 100 recent commands")
        history.togglePinned("oldest")
        check(history.commands.count == 100 && history.commands.first == "oldest" && history.commands.last == "echo 21",
              "unpinning at capacity prunes the oldest ordinary record")
        let restored = ShellCommandHistory(
            commands: [" b ", "a", "b", "c"], pinnedCommands: ["a", "a", "missing", " b "])
        check(restored.pinnedCommands == ["a", "b"] && restored.commands == ["a", "b", "c"],
              "loading drops duplicate and missing pins and restores their order")
        check(restored.rows(for: ShellCommandQuery("# a")!) == [.history("a", isPinned: true)],
              "an exact search keeps the saved record and its management actions")
    }

    private static func testScreenActions() {
        let coordinator = CustomCommandCoordinator()
        coordinator.history = ShellCommandHistory(commands: ["git status", "git"], pinnedCommands: ["git status"])
        let vm = PaletteState()
        vm.query = "# git"
        let screen = ShellCommandScreen(
            query: ShellCommandQuery(vm.query)!, coordinator: coordinator,
            vm: vm, openActions: {}, scrollToFollow: {})
        check(screen.landingSelection == 1, "an exact search selects its saved command below other matching pins")
        let menu = screen.actions(at: 1)!
        check(menu.items.count == 5 && menu.items[2].title == "Pin Command",
              "ordinary history offers pin, move to top, and delete")
        vm.query = "# changed"
        screen.activate(at: 1)
        check(coordinator.lastAction == "run:git", "snapshot activation runs the displayed command")
        menu.items[2].action()
        check(coordinator.lastAction == "pin:git", "pinning addresses the menu's command")
        menu.items[3].action()
        check(coordinator.lastAction == "top:git", "moving to top never invokes execution")
        menu.items[4].action()
        check(coordinator.lastAction == "delete:git" && menu.items[4].isDestructive,
              "deletion addresses the displayed record and is destructive")
        let pinnedMenu = screen.actions(at: 0)!
        check(pinnedMenu.items[2].title == "Unpin Command", "fixed records offer unpinning")
        check(screen.perform(.pin, at: 0) && coordinator.lastAction == "pin:git status",
              "the pin shortcut acts on the selected saved command")
        check(screen.perform(.delete, at: 0) && coordinator.lastAction == "delete:git status",
              "the delete shortcut acts on the selected saved command")
        let typed = ShellCommandScreen(
            query: ShellCommandQuery("# unseen")!, coordinator: coordinator,
            vm: vm, openActions: {}, scrollToFollow: {})
        check(typed.actions(at: 0)?.items.count == 2 && !typed.perform(.pin, at: 0) && !typed.perform(.delete, at: 0),
              "a new command has no history-management actions before it runs")
        check(screen.actions(at: -1) == nil && !screen.secondary(at: 99) && !screen.perform(.delete, at: 99),
              "out-of-range selections cannot mutate history")
        let lastAction = coordinator.lastAction
        screen.activate(at: 99)
        check(coordinator.lastAction == lastAction, "invalid activation is inert")
    }

    private static func check(_ condition: Bool, _ message: String) {
        guard !condition else { return }
        failures += 1
        print("FAIL: \(message)")
    }
}

@MainActor protocol PaletteScreen {}
struct ScrollIntent {}
enum PaletteShortcut { case pin, delete, edit }

@MainActor
@Observable
final class PaletteState {
    var query = ""
    var selection = 0
    var followToken = UUID()
}

@MainActor
final class CustomCommandCoordinator {
    var history = ShellCommandHistory()
    var lastAction = ""
    func shellHistoryRows(for query: ShellCommandQuery) -> [ShellCommandHistory.Row] { history.rows(for: query) }
    func runShellCommand(_ command: String) { lastAction = "run:" + command }
    func editShellCommand(_ command: String) { lastAction = "edit:" + command }
    func togglePinnedShellHistoryCommand(_ command: String) { lastAction = "pin:" + command }
    func moveShellHistoryCommandToTop(_ command: String) { lastAction = "top:" + command }
    func deleteShellHistoryCommand(_ command: String) { lastAction = "delete:" + command }
}

struct PopoverMenuContent {
    let header: String?
    let items: [PopoverMenuItem]
}

struct PopoverMenuItem {
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    init(
        title: String, systemImage: String, startsSection: Bool = false,
        shortcut: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}

struct EmptyResults: View {
    let text: String
    var body: some View { EmptyView() }
}

struct ShellCommandList: View {
    let rows: [ShellCommandHistory.Row]
    let selectedID: String?
    let scroll: ScrollIntent
    let onSelect: (ShellCommandHistory.Row) -> Void
    let onActivate: () -> Void
    let onActions: (ShellCommandHistory.Row) -> Void
    var body: some View { EmptyView() }
}
