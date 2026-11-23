# Notes

Notes edits local Markdown files in a resizable workspace. Its sidebar searches the collection and
filters by pin, pending task or tag. The editor renders Markdown and local images in place.

## Invariants

- **One regular, non-hidden `.md` file is one note.** Its filename without the extension is its title;
  the source contains no frontmatter, embedded ID, or title field, and there is no database or sidecar.
- **A note the user has not named shows its first line instead.** Only the names `create` claims yield
  it, it is presentation and nothing else, and naming the note replaces it.
- **The storage is the source.** The string in `NSTextView`, `NotesStore`, search, and the file are
  identical; rendering is attributes and drawing over that string, never a second string or an offset
  map.
- **The caret's line is raw.** Every line under the selection shows its Markdown; an unfocused editor
  reveals nothing.
- **Styling never reaches undo.** Attribute passes bypass `shouldChangeText`; every edit a Markdown
  gesture makes goes through `NoteTextView.performEdit`.
- **Render Markdown off is the literal editor**, with native Return, Tab and shortcuts and no parsing.
- **The formatting bar is another way to press a shortcut.** Each button sends its chord's
  `NoteEditAction` through `NoteTextView.format`, so it has the chord's gate, undo step and autosave,
  and a button is lit exactly when its toggle would remove that formatting.
- **Only the active note can be dirty.** Switching, creating, renaming, and deleting first flush it, so
  collection navigation cannot abandon an in-memory draft.
- **Saving checks the revision read from disk.** A conflict keeps the draft in memory until the
  user chooses Keep Draft or Load Disk Version.
- **The sidebar indexes metadata.** Listings extract previews, tags and counts. Autosave reuses
  summaries for unchanged neighbours. A nonempty query still searches file bodies off-main.
- **Off means no entry point or Notes work.** The feature is off by default; its shortcuts no-op, its
  commands are absent, and enabling alone does not enumerate or create the Notes directory.
- **The collection may be empty.** Deleting the last note is allowed and creates no replacement; the
  window shows its empty state and Create Note still works from there.
- **Editing preserves the window frame.** The document scrolls inside the saved window. Expanding
  or collapsing the sidebar holds the right edge in place within the display's visible frame.
- **The editor is a surface snippets expand into.** `NoteTextView` adopts `InjectableTextView`,
  so a typed keyword — and the Snippets browser's ↵ — is written straight into the text storage
  rather than posted as events at whichever app happens to be frontmost. Quick Actions also read and
  replace its selected text in process. Only AI Chat's composer adopts it too: see
  [snippets.md](snippets.md#text-delivery-and-pasteboard-safety).

## Storage and identity

The per-channel directory is:

```text
~/Library/Application Support/<bundle-id>/Notes/
```

**Notes Folder** in the Notes pane, or `notes.folder` in the [settings file](settings-file.md), uses
another folder, absolute or under `~/`, as it is: nothing moves out of the old one. `NotesStore.relocate`
saves the open draft where it was before it lists the new folder. The folder is excluded from backups,
since it names a place on this Mac.

`NoteID` is the relative filename. A rename therefore returns a new identity; there are no per-note
launcher items, hotkeys, favorites, or visibility settings that could retain the old one. Immediate
regular `.md` children are sorted by modification date, then localized title. Subdirectories, hidden
files, and symbolic links are ignored.

Create uses `Untitled.md`, then `Untitled 2.md`, and so on, and rename claims a free name by the same
rule. `importNotes` claims one the same way, so a note restored from a backup lands beside the note it
shares a title with rather than over it. Collisions with *another* note are case- and diacritic-insensitive, so `plán` beside `Plan`
becomes `plán 2.md`. A note never collides with itself: only an exact filename match is a no-op, which
is what lets a rename change nothing but the case or the accents. The active filename is local UI state
in UserDefaults and does not ride settings backups.

## Derived titles

A note still carrying a name `create` claimed — `Untitled`, `Untitled 2`, … — shows the first line of
its source that carries visible text. `NoteTitle` owns that rule: blank, rule and fence lines are
skipped, block and inline Markdown markers are dropped whether or not rendering is on, and the line is
capped to 120 characters so no row or title bar has to carry a paragraph. `NoteSummary.title` remains the filename; `displayTitle` is what every
surface renders — switcher rows and their VoiceOver labels, the Trash confirmation, the window title,
and the title band of `NoteSearch`, so a fuzzy query reaches a note nobody has named.
An empty unnamed note displays a localized Untitled label, preserving its filename and numeric suffix.

The active title follows the live draft. The sidebar receives saved titles and metadata after the
300 ms autosave. A standalone local image reference is skipped when deriving an unnamed note's title.
Renaming starts with the filename itself.

`NotesRepository` owns list, create, load, save, rename, Trash, and search reads. Every
URL is validated as an immediate child of the injected directory. It lives in `Service/` because it
performs filesystem effects; `NotesStore` drives its blocking work from detached tasks.

## Ownership and enablement

`AppCore` owns `NotesStore` and lazily constructs `NotesCoordinator`. `NotesView` receives only the
coordinator through `@Environment`; it never receives `AppCore` or mutates the store.

Settings > Notes owns `AppSettings.notesEnabled`, which is false when absent. The pane lists **Show
Notes**, **Create Note**, and **Search Notes** from `CommandCatalog`, so it can still render them while
`AppIndex` omits them. It is their only pane: `SettingsTab.ownedCommands` names the three, which takes
them out of Settings > Commands and out of reach of `Enable Commands` — Notes' own switch is the one
that decides they exist.

`AppCore` observes enablement and calls `NotesCoordinator.applyEnabled()`. Disabling hides the panel,
invalidates pending presentation work, cancels search, flushes the draft, and removes the commands. A
failed flush retains the draft for retry.

## Workspace and keyboard

Show Notes toggles the workspace. Create Note opens the sidebar, creates a unique file and focuses
the editor. Search Notes, ⌘P and ⇧⌘F open the sidebar and focus its search field. Arrow keys navigate
matches and Return selects one. Pins sort first, followed by modification time. Click a title to
rename its file. Click a rendered hashtag to filter the sidebar.

The initial split frame is 960 × 660 pt with a 260 pt sidebar, and the compact frame is 680 × 660 pt.
The minimum sizes are 760 × 520 pt and 480 × 440 pt. ⌘\ toggles the sidebar. Double-click the
free title band to place the panel at the top right of its display. The title-bar pin changes the
window level, while ⌥⌘P pins the current note in the collection. Sidebar visibility, window level,
pinned filenames, stats mode and toolbar expansion are local UserDefaults state.

⌥⌘O opens the H1–H3 outline. Choosing a heading scrolls to its UTF-16 source range and flashes it.
The actions menu offers Markdown and plain-text copy, image import, Finder, cleanup and Trash.
⇧⌘C copies Markdown, ⌘O reveals the file, ⌘F opens native Find and ⌘⌫ requests Trash confirmation.
Escape dismisses the active transient control before hiding the workspace and restoring focus.

## Local images

Paste a screenshot, drop an image or use Insert Image. Finder file URLs take precedence over icon
bitmaps. Imported files keep their format and pasted bitmaps become PNGs. Identical image bytes reuse
the same asset. The first import creates `assets/` under the selected Notes folder. Moving a
collection with its images requires copying that subdirectory alongside the Markdown files.

Standalone `![alt](assets/file.png)` references become TextKit 2 layout fragments. ImageIO
downsamples previews off-main. The pixel cache has a 64 MiB cost limit and keys entries by file,
modification date and display scale. The source line stays editable above its card. A missing image
displays a placeholder. Single-click selects the reference and double-click opens the original.
The preview supports zoom, ⌘C to copy, ⌘O to reveal and Escape or Space to close.

Removing a reference preserves its file for undo. Clean Unused Images asks for confirmation and
moves unreferenced Tinycast-named images to Trash. Asset access rejects hidden components, traversal
and symlinks. Documents never cause a network image request.

## Editor

`NoteEditorView` is one TextKit 2 `NSTextView` inside an `NSScrollView`. It installs
`NoteEditorInput.source` as `NSTextView.string` and never swaps that string for a display version.
Rendering is attributes and drawing over the source.

### Parsing

`Model/NoteMarkdownParser` splits the source on the same boundaries as `NSString.lineRange(for:)`, so
one line is one TextKit paragraph. `NoteMarkdown` gives each line its kind, UTF-16 ranges for its
content, block marker and task checkbox, and a list level from an indent stack. A source ending in a
terminator, and an empty source, get a final zero-length line, so a caret on the empty last row sits on
a real line like any other. Inline spans are not stored: `NoteMarkdown.inlines(of:)` scans the one line
asked for, which is all the styler, the editing rules and `NoteTitle` ever need.

It covers headings 1 to 6 (4 to 6 look like 3), bold, italic, bold italic, strikethrough, inline code,
links, bare `http` and `https` URLs, bullet, numbered and task lists with nesting, quotes, fenced code
blocks and horizontal rules. Inline spans never cross a line. Inline images, underline, HTML, setext headings,
indented code, footnotes, reference links and blocks nested inside quotes stay plain text. A GFM table
(a pipe row, a delimiter row with as many cells, then the pipe rows after it) also stays plain text, but
is recognised so it gets no inline styling: it shows in the code font, with wrapped rows hanging under
their first line, and a delimiter row typed under existing rows restyles all of them.
The whole note is reparsed on each edit. The AI chat's `MarkdownBlock` is a separate read-only parser
and is not shared.

### Rendering

`UI/NoteMarkdownRenderer` holds the parse and the set of revealed lines, and is the text storage's
delegate. Every mutation reports its edited range and length delta there, including the undo, redo and
marked-text ones that post no `textDidChange`, and several are folded into one pending edit.
`textDidChange`, `textViewDidChangeSelection` and any read of the parse consume it and reparse. The
edited lines and one neighbour on each side are restyled, widened to the rest of the note when a fenced
block moved and to any list line whose depth changed.

`NoteMarkdownStyler` turns one line into attributes. `NoteMarkdownTypography` sets the body one
system text style up (title3) and headings at largeTitle, title1 and title2, with or without
rendering; Interface Size does not scale Notes. A hidden marker gets a 0.01-point system font and
a clear colour, so it stays in the string at almost no width. Fence and rule lines are cleared at their
normal font instead, so they keep their row height. Every list item (bullet, numbered or task) gets 8
points of space after it, rendered or revealed, so items read as separate rows and moving the caret
never shifts them; a wrapped item keeps normal line spacing. A restyle writes straight to `NSTextStorage` inside
`beginEditing` and `endEditing`, then invalidates layout for those lines. It never calls
`shouldChangeText`, which is what keeps styling off the undo stack.

A bullet or numbered marker becomes a list only after a space or tab; a lone `-` or `1.` stays literal.

`NoteRevealPolicy` picks the lines that show raw Markdown: every line under the selection, plus both
fences of a code block the selection is in. Nothing is revealed unless the editor is first responder in
the key window. Revealed markers use `textTertiary`. During a drag selection the reveal waits for
mouse-up, because revealing moves text under the pointer. Bullets keep their dot under the caret;
other revealed list markers keep the rendered marker's `textSecondary` colour. Revealed non-bullet list
and quote lines hang their source marker left of the content indent, so text stays where the rendered
line had it. Empty list items keep body-sized invisible markers so their line height does not collapse.
Other caret lines are raw, keeping the caret out of hidden text.

### Block drawing

`NoteLayoutFragmentProvider` is the text layout manager's delegate. A paragraph whose first character
carries a `NoteBlockDecoration` is laid out by `NoteBlockLayoutFragment`, which draws code bands with
their language label, quote bars, rules, bullets, the source's own list numbers, and checkboxes, all
list markers in a neutral gray. Vertical
spacing comes from paragraph styles: overriding the fragment's frame would leave the caret above the
glyphs. A marker sits on the item's first line of text, not its first line fragment: a first word
too wide for the line wraps below the hidden marker, leaving the marker a line of almost no height,
and the checkbox hit test reads the same line. There are no text attachments, overlay controls,
`NSTextList`, `NSTextTable` or private API.

### Editing

`Model/NoteMarkdownEditing` turns a gesture into a `NoteEditPlan`, one replacement plus the selection
after it. Nil means AppKit handles the key natively. `NoteTextView.performEdit` applies a plan through
`shouldChangeText`, `replaceCharacters` and `didChangeText`, so each gesture is one undo step and
reaches autosave.

- Return continues a list or quote and leaves it on an empty item. Tab and Shift-Tab nest list items
  by four spaces. Backspace at an item's content start outdents it, then removes its marker. These
  edits renumber the ordered run they touch in the same undo step.
- Typing `[] ` or `[ ] ` at the start of a paragraph makes `- [ ] `.
- ⌥⌘C wraps the touched lines in a fenced block, or removes the fences of the block the selection is
  in. On an empty line it opens an empty block with the caret inside.
- ⇧⌘B adds `> ` to each touched line, or removes one `>` from each when all of them are quotes. Blank
  lines inside a selection, code, tables and rules are left alone.
- Pasting a single `http` or `https` URL over text selected on one line makes `[text](url)`.
- Clicking a checkbox toggles `[ ]` and `[x]` without moving the caret. The hit test uses
  `NoteCheckboxGeometry`, the rect the fragment draws, grown by 3 points.
- Clicking a rendered link opens it, unless the click lands in the outer 30% of the label's first or
  last glyph, which places the caret. Only `http`, `https` and `mailto` open. A revealed line carries
  no link attribute, so its URL is edited as text.

| Shortcut | Does |
| --- | --- |
| ⌘Z, ⇧⌘Z | undo, redo |
| ⌘B, ⌘I, ⌘E | bold, italic, inline code |
| ⇧⌘X | strikethrough |
| ⌥⌘C | code block |
| ⇧⌘B | quote |
| ⌘K | link |
| ⇧⌘7, ⇧⌘8, ⇧⌘9 | numbered, bullet, task list |
| ⌥⌘1, ⌥⌘2, ⌥⌘3 | heading 1, 2, 3 |
| ⌥⌘0 | plain paragraph |

Digits match by key code. The text view sees these chords before `NotesPanel` claims its own, and none
collide. In a note, ⌘E replaces AppKit's Use Selection for Find.

AppKit still owns typing, selection, Cut, Copy, Paste, Select All, Find, marked text, emoji, combining
characters and undo grouping. The editor handles ⌘Z and ⇧⌘Z while focused, including in the
non-activating panel and with rendering off. Its native undo manager holds one linear history in
memory; editing after undo discards redo. The coordinator observes undo and redo completion with
main-actor notifications, so both reach autosave, rendering, formatting and the character count.
Copy yields raw Markdown and VoiceOver reads the source. Changing the note
identity or editor epoch reinstalls and restyles the string and clears the previous document's undo
history. Snippets expand through `insertText` and are styled like typed text. The empty-note placeholder
is drawn in the text view, so opening the find bar moves it with the editor content.

### The formatting bar

Show Formatting Bar enables the bottom capsule. The paintbrush and ⌥⌘T expand its controls. With
rendering enabled the capsule includes bold, italic, inline code, links, quotes, bullets, tasks,
images, rules and timestamps. The other formatting shortcuts remain available in the editor.
Rendered / Raw and ⌥⌘R change the Render Markdown setting. The counter cycles through characters,
words and reading time, and task and image totals. Narrow windows can scroll the expanded tools.

## Autosave

Editor changes update the main-actor draft immediately and debounce save for 300 milliseconds. Only the
active source is retained. A successful save refreshes metadata ordering; switching waits for the same
flush before loading another source. Termination awaits that flush before the app exits, but never
vetoes the quit.

Every store save compares its expected SHA-256 revision with the file inside a coordinated write.
An external edit displays an inline recovery bar. Keep Draft retries against the conflicting revision,
so another external edit can raise a fresh conflict. Load Disk Version rereads the file and resets
undo history. Reopening reloads a clean active note and preserves a dirty draft.

## Verification

`Tests/notes-test.swift` compiles the shipped Notes model and service sources with the real fuzzy
matcher. It covers repository safety, unique-name claiming, derived titles, search, selection,
autosave, external reloads, draft preservation, empty collections, switcher interaction, and
cancellation, plus the Markdown parser, every edit plan, the formatting each selection reports and the
reveal policy.

`Tests/notes-editor-test.swift` uses real TextKit 2 and AppKit undo objects. It runs the native
Cut/Copy/Paste, the native find bar, Unicode and marked-text cases with rendering off and on, and covers
undo isolation, undo and redo shortcut routing, source publication and character count, linear history,
exact source after styling, hidden and revealed markers, restyling after edits and after undo, block
decorations and layout fragments, list keys, chords, the task rule, checkbox toggles, link schemes,
pasting a URL, and the formatting reports and `format(_:)` the formatting bar uses.
`Tests/notes-editor-performance.swift` times install, typing, scrolling and caret
moves on a 100,000-character note with 20 image references. See `docs/testing.md` for the command and
the Notes manual sweep in `docs/testing.md` covers commands, shortcuts, switcher, focus restoration,
Finder, Trash recovery, and accessibility.
