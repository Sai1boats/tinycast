import Foundation
import Observation

@MainActor
@Observable
final class ShellCommandHistoryStore {
    private static let defaultsKey = "shellCommandHistory"
    private static let pinnedDefaultsKey = "shellCommandHistoryPins"
    private let defaults: UserDefaults
    private(set) var history: ShellCommandHistory

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        history = ShellCommandHistory(
            commands: defaults.stringArray(forKey: Self.defaultsKey) ?? [],
            pinnedCommands: defaults.stringArray(forKey: Self.pinnedDefaultsKey) ?? [])
    }

    func record(_ command: String) {
        var updated = history
        updated.record(command)
        commit(updated)
    }

    func remove(_ command: String) {
        var updated = history
        updated.remove(command)
        commit(updated)
    }

    func togglePinned(_ command: String) {
        var updated = history
        updated.togglePinned(command)
        commit(updated)
    }

    func moveToTop(_ command: String) {
        var updated = history
        updated.moveToTop(command)
        commit(updated)
    }

    private func commit(_ updated: ShellCommandHistory) {
        guard updated != history else { return }
        history = updated
        defaults.set(updated.commands, forKey: Self.defaultsKey)
        defaults.set(updated.pinnedCommands, forKey: Self.pinnedDefaultsKey)
    }
}
