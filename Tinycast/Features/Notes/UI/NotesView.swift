import SwiftUI

struct NotesView: View {
    @Environment(NotesCoordinator.self) private var notes

    var body: some View {
        HStack(spacing: 0) {
            if notes.isSidebarVisible {
                NoteSidebarView()
                Rectangle().fill(Theme.Colors.separator).frame(width: Theme.Size.hairline)
            }
            VStack(spacing: 0) {
                NoteEditorHeaderView()
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        if case .conflict = notes.saveState {
                            HStack {
                                Text("Modified on disk").foregroundStyle(.secondary)
                                Spacer()
                                Button("Keep Draft") { notes.resolveConflict(keepDraft: true) }
                                Button("Load Disk Version") { notes.resolveConflict(keepDraft: false) }
                            }.padding(Theme.Spacing.md).background(Theme.Colors.cardFill)
                        }
                        content
                    }
                    if let menu = notes.menu {
                        Color.clear.contentShape(Rectangle()).onTapGesture { notes.menu = nil }
                        Group {
                            switch menu {
                            case .outline: NoteOutlinePopoverView()
                            case .actions: NoteActionsMenuView()
                            }
                        }.padding(.trailing, Theme.Spacing.xl)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.panelScrim)
        .background(GlassEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        // The band above is the title bar; AppKit must not inset the content a second time.
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        if notes.hasActiveNote {
            editorSurface
        } else {
            emptyState
        }
    }

    private var editorSurface: some View {
        VStack(spacing: 0) {
            NoteEditorView(
                notesDirectory: notes.notesDirectory, input: notes.editorInput,
                rendersMarkdown: notes.rendersMarkdown,
                onSourceChange: notes.updateSource,
                onCharacterCountChange: notes.updateCharacterCount,
                onFormattingChange: notes.updateFormatting,
                onReady: notes.editorReady
            )
            if notes.showsFormattingBar {
                formattingBand
            } else {
                footer
            }
        }
    }

    /// The count hides first, and the band keeps the offered width so the bar never widens a note.
    private var formattingBand: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                characterCount
                Color.clear.frame(width: 0)
            }
            Spacer(minLength: 0)
            ViewThatFits(in: .horizontal) {
                NoteFormattingBar().fixedSize()
                ScrollView(.horizontal) { NoteFormattingBar() }.scrollIndicators(.hidden)
            }.layoutPriority(1)
        }
        .padding(.leading, Theme.Size.noteEditorInset)
        .padding(.trailing, Theme.Spacing.md)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        .frame(height: Theme.Size.bottomBarHeight)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SymbolImage(name: "text.page", size: Theme.Size.noteEmptyGlyph)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No Notes")
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Create Note", action: notes.createNote)
                .buttonStyle(.plain)
                .font(Theme.Typography.bar)
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(height: Theme.Size.barButtonHeight)
                .frosted(in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        characterCount
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Size.noteFooterHeight)
    }

    private var characterCount: some View {
        Button(notes.statsLabel, action: notes.cycleStats)
            .buttonStyle(.plain)
            .font(Theme.Typography.rowTrailing)
            .foregroundStyle(Theme.Colors.textTertiary)
            .lineLimit(1)
            .accessibilityLabel(notes.statsLabel)
    }
}

struct NoteTitlebarDragRegion: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> NoteTitlebarDragView {
        let view = NoteTitlebarDragView()
        view.onDoubleClick = onDoubleClick
        return view
    }
    func updateNSView(_ view: NoteTitlebarDragView, context: Context) {
        view.onDoubleClick = onDoubleClick
    }
}

/// Measures the band only: macOS 27.2 starts no move from `performDrag(with:)`.
final class NoteTitlebarDragView: NSView {
    var onDoubleClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        (window as? NotesPanel)?.claimsTitleBarDoubleClick = { [weak self] event in
            self?.claimDoubleClick(event) ?? false
        }
    }

    private func claimDoubleClick(_ event: NSEvent) -> Bool {
        guard let window, bounds.contains(convert(event.locationInWindow, from: nil)),
            // The traffic lights sit inside the band; a double-click on one stays theirs.
            !(window.contentView?.superview?.hitTest(event.locationInWindow) is NSButton)
        else { return false }
        onDoubleClick?()
        return true
    }
}
