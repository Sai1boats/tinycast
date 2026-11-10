import SwiftUI

struct QRCodeScreen: PaletteScreen {
    let coordinator: QRCodeCoordinator
    let vm: PaletteState
    let openActions: () -> Void

    var rows: [QRCodeEntry] { coordinator.history.entries }
    var actsWithoutRows: Bool { true }
    var primaryActionTitle: String { String(localized: "Generate QR Code") }

    func isPrimaryActionEnabled(at selection: Int) -> Bool {
        !coordinator.isBusy && !vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func hasActions(at selection: Int) -> Bool { !rows.isEmpty }

    func activate(at selection: Int) { coordinator.generate() }

    func secondary(at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        coordinator.copy(entry)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        switch shortcut {
        case .delete: coordinator.remove(entry)
        default: return false
        }
        return true
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let entry = entry(at: selection) else { return nil }
        return PopoverMenuContent(header: entry.title, items: [
            PopoverMenuItem(title: String(localized: "Copy Image"), systemImage: "doc.on.doc", shortcut: "⌘↵") {
                coordinator.copy(entry)
            },
            PopoverMenuItem(title: String(localized: "Save Image…"), systemImage: "square.and.arrow.down") {
                coordinator.save(entry)
            },
            PopoverMenuItem(
                title: String(localized: "Delete Entry"), systemImage: "trash", startsSection: true,
                shortcut: "⌃X", isDestructive: true
            ) {
                coordinator.remove(entry)
            }
        ])
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(
            QRCodeView(
                entries: rows, selected: entry(at: selection), scroll: scroll,
                onSelect: { entry in
                    if let index = rows.firstIndex(of: entry) { vm.selection = index }
                },
                onActions: { entry in
                    if let index = rows.firstIndex(of: entry) { vm.selection = index }
                    openActions()
                })
                .onAppear { coordinator.load() }
        )
    }

    private func entry(at selection: Int) -> QRCodeEntry? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }
}
