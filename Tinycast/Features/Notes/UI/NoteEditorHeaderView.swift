import SwiftUI

struct NoteToolButton: View {
    let symbol: String
    let title: String
    let selected: Bool
    let action: () -> Void

    init(_ symbol: String, _ title: String, selected: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.selected = selected
        self.action = action
    }

    var body: some View {
        BarButton(isSelected: selected, isCompact: true, action: action) {
            SymbolImage(name: symbol, size: Theme.Size.noteGlyph)
        }.focusable(false).accessibilityLabel(title).tooltip(title)
    }
}

struct NoteEditorHeaderView: View {
    @Environment(NotesCoordinator.self) private var notes
    @FocusState private var renaming: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            NoteToolButton(
                "sidebar.left", String(localized: "Toggle Sidebar") + "  ⌘\\",
                selected: notes.isSidebarVisible, action: notes.toggleSidebar)
            if notes.isRenamingSwitcherNote {
                TextField("Title", text: notes.switcherTitleDraftBinding)
                    .textFieldStyle(.plain).focused($renaming)
                    .onAppear { renaming = true }
                    .onSubmit(notes.commitSwitcherRename)
                    .onExitCommand(perform: notes.cancelSwitcherRename)
                    .onChange(of: renaming) { _, focused in if !focused { notes.commitSwitcherRename() } }
            } else {
                Button(notes.activeTitle) {
                    if let note = notes.activeSummary { notes.beginSwitcherRename(note) }
                }.buttonStyle(.plain).font(Theme.Typography.noteTitle).lineLimit(1)
            }
            if notes.hasActiveNote {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle().fill(status.1).frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                    Text(status.0).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)
                .overlay { NoteTitlebarDragRegion(onDoubleClick: notes.moveToTopRight) }
            HStack(spacing: Theme.Spacing.xxs) {
                NoteToolButton(
                    "text.alignleft", String(localized: "Outline") + "  ⌥⌘O", selected: notes.menu == .outline
                ) {
                    notes.toggleMenu(.outline)
                }
                NoteToolButton(
                    notes.isAlwaysOnTop ? "pin.fill" : "pin", String(localized: "Always on Top"),
                    selected: notes.isAlwaysOnTop, action: notes.toggleFloating)
                NoteToolButton(
                    "ellipsis", String(localized: "More Actions"), selected: notes.menu == .actions
                ) {
                    notes.toggleMenu(.actions)
                }
            }.padding(Theme.Spacing.xs).frosted(in: Capsule())
        }
        .padding(.leading, notes.isSidebarVisible ? Theme.Spacing.xl : Theme.Size.noteTrafficLightInset * 4)
        .padding(.trailing, Theme.Spacing.xl).frame(height: Theme.Size.noteTitlebar)
    }

    private var status: (String, Color) {
        switch notes.saveState {
        case .saved: (String(localized: "Saved"), .green)
        case .saving: (String(localized: "Saving…"), .orange)
        case .failed: (String(localized: "Couldn’t save"), .red)
        case .conflict: (String(localized: "Modified on disk"), .orange)
        }
    }
}
