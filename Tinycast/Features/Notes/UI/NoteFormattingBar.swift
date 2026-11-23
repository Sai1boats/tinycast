import SwiftUI

struct NoteFormattingBar: View {
    @Environment(NotesCoordinator.self) private var notes

    private struct Control: Sendable {
        let symbol: String
        let title: String
        let shortcut: String
        let action: NoteEditAction
        let isLit: @Sendable (NoteFormatting) -> Bool
    }

    private static let styles = [
        Control(
            symbol: "bold", title: String(localized: "Bold"), shortcut: "⌘B",
            action: .toggleInline(.bold)
        ) {
            $0.inlineStyles.contains(.bold)
        },
        Control(
            symbol: "italic", title: String(localized: "Italic"), shortcut: "⌘I",
            action: .toggleInline(.italic)
        ) {
            $0.inlineStyles.contains(.italic)
        },
        Control(
            symbol: "chevron.left.forwardslash.chevron.right", title: String(localized: "Inline Code"),
            shortcut: "⌘E", action: .toggleInline(.code)
        ) { $0.inlineStyles.contains(.code) },
        Control(symbol: "link", title: String(localized: "Link"), shortcut: "⌘K", action: .toggleLink) {
            $0.isLink
        }
    ]

    private static let blocks = [
        Control(
            symbol: "text.quote", title: String(localized: "Quote"), shortcut: "⇧⌘B",
            action: .toggleQuote
        ) { $0.isQuote }
    ]

    private static let lists = [
        Control(
            symbol: "list.bullet", title: String(localized: "Bullet List"), shortcut: "⇧⌘8",
            action: .toggleList(.bullet)
        ) {
            $0.list == .bullet
        },
        Control(
            symbol: "checklist", title: String(localized: "Task List"), shortcut: "⇧⌘9",
            action: .toggleList(.task)
        ) {
            $0.list == .task
        }
    ]

    var body: some View {
        let formatting = notes.formatting
        let isExpanded = notes.isFormattingBarExpanded
        HStack(spacing: Theme.Spacing.sm) {
            if isExpanded {
                HStack(spacing: Theme.Spacing.sm) {
                    BarButton(isSelected: !notes.rendersMarkdown, isCompact: true, action: notes.toggleRaw) {
                        Label(
                            notes.rendersMarkdown ? String(localized: "Rendered") : "Raw", systemImage: "eye"
                        )
                        .font(.caption)
                    }.focusable(false).accessibilityLabel("Render Markdown")
                    if notes.rendersMarkdown {
                        group(Self.styles, formatting)
                        group(Self.blocks, formatting)
                        group(Self.lists, formatting)
                        NoteToolButton("photo", String(localized: "Insert Image"), action: notes.pickImage)
                        NoteToolButton("minus", String(localized: "Horizontal Rule")) {
                            notes.format(.insertSnippet(text: "\n---\n", caretOffset: 5))
                        }
                        NoteToolButton("clock", String(localized: "Timestamp")) {
                            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
                            notes.format(.insertSnippet(text: stamp, caretOffset: stamp.utf16.count))
                        }
                    }
                }
                // Grows out of the round button; nothing leaves the capsule, so no clip is needed.
                .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
            }
            NoteFormattingToggle(isExpanded: isExpanded, action: notes.toggleFormattingBar)
                // Drawn above the buttons, so they grow out from behind it.
                .zIndex(1)
        }
        .padding(Theme.Spacing.xs)
        // Behind the buttons, not around them: glass clips content, tooltips draw outside it.
        .background { Capsule().fill(Color.clear).frosted(in: Capsule()) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Formatting")
    }

    private func group(_ controls: [Control], _ formatting: NoteFormatting) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(controls, id: \.title) { control in
                let lit = control.isLit(formatting)
                BarButton(isSelected: lit, isCompact: true, action: { notes.format(control.action) }) {
                    NoteBarGlyph(name: control.symbol)
                }
                .focusable(false)
                .accessibilityLabel(control.title)
                .accessibilityAddTraits(lit ? .isSelected : [])
                .tooltip("\(control.title)  \(control.shortcut)")
            }
        }
    }
}

private struct NoteFormattingToggle: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        BarButton(isSelected: isExpanded, isCompact: true, action: action) {
            NoteBarGlyph(name: "paintbrush")
        }
        .focusable(false)
        .accessibilityLabel("Formatting")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        // Against the window's trailing edge, so a centred label would run off it.
        .tooltip(String(localized: "Formatting  ⌥⌘T"), alignment: .trailing)
    }
}

/// Symbols differ in width, so a fixed frame keeps every button the same square.
private struct NoteBarGlyph: View {
    let name: String

    var body: some View {
        SymbolImage(name: name, size: Theme.Size.noteGlyph)
            .frame(width: Theme.Size.noteGlyph, height: Theme.Size.noteGlyph)
    }
}
