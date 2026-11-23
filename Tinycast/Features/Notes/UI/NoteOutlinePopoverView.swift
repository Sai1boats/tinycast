import SwiftUI

struct NoteOutlinePopoverView: View {
    @Environment(NotesCoordinator.self) private var notes

    var body: some View {
        let headings = notes.headings
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Outline").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if headings.isEmpty {
                Text("No headings").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(headings) { heading in
                            Button {
                                notes.jump(to: heading)
                            } label: {
                                HStack {
                                    Text(verbatim: "H\(heading.level)").font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Text(heading.title).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(.leading, CGFloat(heading.level - 1) * Theme.Spacing.xl)
                                    .padding(.vertical, Theme.Spacing.xs).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }.padding(Theme.Spacing.xl)
            .frame(width: Theme.Size.noteOutlineMenu.width, alignment: .leading)
            .frame(maxHeight: Theme.Size.noteOutlineMenu.height, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Theme.Colors.noteText)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.menuPanel))
    }
}
