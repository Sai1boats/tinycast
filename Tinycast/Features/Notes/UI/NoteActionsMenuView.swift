import SwiftUI

struct NoteActionsMenuView: View {
    @Environment(NotesCoordinator.self) private var notes

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            row(String(localized: "Copy as Markdown"), "⇧⌘C") { notes.copyNote(plain: false) }
            row(String(localized: "Copy as Plain Text")) { notes.copyNote(plain: true) }
            row(String(localized: "Insert Image")) { notes.pickImage() }.disabled(!notes.rendersMarkdown)
            row(String(localized: "Show in Finder"), "⌘O", notes.openNotesFolder)
            row(String(localized: "Clean Unused Images"), "", notes.cleanImages)
            Divider()
            row(String(localized: "Move to Trash"), "⌘⌫") {
                if let id = notes.activeSummary?.id { notes.trash(id) }
            }.foregroundStyle(.red)
        }
        .padding(Theme.Spacing.sm).frame(width: Theme.Size.noteActionsMenuWidth)
        .foregroundStyle(Theme.Colors.noteText)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.menuPanel))
    }

    private func row(_ title: String, _ chord: String = "", _ action: @escaping () -> Void) -> some View {
        Button {
            notes.menu = nil; action()
        } label: {
            HStack {
                Text(title); Spacer(); Text(chord).font(.caption).foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.sm).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
