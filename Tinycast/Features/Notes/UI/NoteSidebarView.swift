import SwiftUI

struct NoteSidebarView: View {
    @Environment(NotesCoordinator.self) private var notes
    @FocusState private var searchFocused: Bool
    @State private var filterHeight = Theme.Size.noteSearchHeight

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                NoteToolButton("plus", String(localized: "Create Note") + "  ⌘N", action: notes.createNote)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(height: Theme.Size.noteTitlebar)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search notes…", text: notes.searchQueryBinding)
                        .textFieldStyle(.plain).focused($searchFocused)
                        .onSubmit { notes.selectSwitcherNote() }
                        .onExitCommand {
                            searchFocused = false; notes.closeSwitcher()
                        }
                    if !notes.searchQueryBinding.wrappedValue.isEmpty {
                        Button {
                            notes.searchQueryBinding.wrappedValue = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }.accessibilityLabel("Clear Search")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(height: Theme.Size.noteSearchHeight)
                .background(Theme.Colors.cardFill, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Colors.separator)
                }
                ScrollView { filters }
                    .scrollBounceBehavior(.basedOnSize)
                    .onScrollGeometryChange(for: CGFloat.self) {
                        $0.contentSize.height
                    } action: { _, height in
                        filterHeight = height
                    }
                    .frame(height: min(filterHeight, Theme.Size.noteTitlebar * 2))

            }
            .padding(.horizontal, Theme.Size.noteTrafficLightInset)
            .padding(.bottom, Theme.Spacing.xl)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xxs) {
                        ForEach(notes.visibleNotes) { note in
                            NoteSidebarRow(
                                summary: note,
                                selected: (searchFocused ? notes.switcherSelection : notes.editorInput.id)
                                    == note.id
                            )
                            .id(note.id)
                        }
                        if notes.visibleNotes.isEmpty {
                            Text(notes.isSearching ? "Searching notes…" : "No notes found")
                                .foregroundStyle(.secondary).padding()
                        }
                    }.padding(.horizontal, Theme.Spacing.lg)
                }
                .onChange(of: notes.switcherSelection) { _, id in if let id { proxy.scrollTo(id) } }
            }
            Divider()
            HStack {
                Text("\(notes.noteCount) notes")
                Spacer()
                Button("Open Folder") { NSWorkspace.shared.open(notes.notesDirectory) }
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.xl).frame(height: Theme.Size.bottomBarHeight)
        }
        .frame(width: Theme.Size.noteSidebarWidth)
        .buttonStyle(.plain)
        .onChange(of: notes.switcherFocusRevision, initial: true) { _, _ in
            if notes.isSwitcherPresented { searchFocused = true }
        }
        .onChange(of: notes.visibleNotes) { _, _ in notes.reconcileSwitcherSelection() }
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
    }

    private var filters: some View {
        NoteFilterLayout {
            chip(String(localized: "All"), .all)
            chip(String(localized: "Pinned"), .pinned)
            chip(String(localized: "Tasks"), .tasks)
            ForEach(notes.availableTags, id: \.self) { chip("#" + $0, .tag($0)) }
        }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        guard searchFocused else { return .ignored }
        notes.moveSwitcherSelection(by: offset)
        return .handled
    }

    private func chip(_ title: String, _ filter: NoteSidebarFilter) -> some View {
        Button {
            notes.sidebarFilter = notes.sidebarFilter == filter ? .all : filter
        } label: {
            Text(title).lineLimit(1).font(.caption)
                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.xxs)
                .background(
                    notes.sidebarFilter == filter ? Theme.Colors.selection : Theme.Colors.cardFill,
                    in: Capsule())
        }
        .accessibilityAddTraits(notes.sidebarFilter == filter ? .isSelected : [])
    }
}

private struct NoteSidebarRow: View {
    @Environment(NotesCoordinator.self) private var notes
    let summary: NoteSummary
    let selected: Bool
    @State private var hovered = false

    var body: some View {
        let pinned = notes.pinnedIDs.contains(summary.id)
        Button {
            notes.activateSwitcherNote(summary.id)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    if pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.tint) }
                    Text(summary.displayTitle).font(.headline).lineLimit(1)
                    Spacer(minLength: Theme.Size.noteGlyph)
                }
                Text(summary.preview ?? " ").lineLimit(1).font(.callout).foregroundStyle(.secondary)
                HStack(spacing: Theme.Spacing.sm) {
                    Text(summary.modifiedAt, format: .relative(presentation: .named))
                    Spacer()
                    if summary.imageCount > 0 { Label("\(summary.imageCount)", systemImage: "photo") }
                    if summary.totalTaskCount > 0 {
                        Label(
                            "\(summary.totalTaskCount - summary.pendingTaskCount)/\(summary.totalTaskCount)",
                            systemImage: "checklist")
                    }
                }.font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.lg).contentShape(Rectangle())
        }
        .background(
            selected ? Theme.Colors.selection : hovered ? Theme.Colors.rowHover : .clear,
            in: .rect(cornerRadius: Theme.Radius.row)
        )
        .overlay(alignment: .topTrailing) {
            if hovered {
                Button {
                    notes.togglePin(summary.id)
                } label: {
                    Image(systemName: pinned ? "pin.slash" : "pin")
                }
                .accessibilityLabel(pinned ? String(localized: "Unpin") : String(localized: "Pin Note"))
                .padding(Theme.Spacing.sm)
            }
        }
        .onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: "Pin Note") { notes.togglePin(summary.id) }
        .accessibilityAction(named: "Move to Trash") { notes.trash(summary.id) }
    }
}

private struct NoteFilterLayout: Layout {
    private func layout(width: CGFloat, views: Subviews) -> ([CGPoint], CGSize) {
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for view in views {
            let size = view.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > width {
                cursor.x = 0
                cursor.y += rowHeight + Theme.Spacing.xs
                rowHeight = 0
            }
            positions.append(cursor)
            cursor.x += size.width + Theme.Spacing.xs
            rowHeight = max(rowHeight, size.height)
        }
        return (positions, CGSize(width: width, height: cursor.y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(width: proposal.width ?? Theme.Size.noteSidebarWidth, views: subviews).1
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (position, view) in zip(layout(width: bounds.width, views: subviews).0, subviews) {
            view.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
}
