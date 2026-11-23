import AppKit
import SwiftUI

@MainActor
@Observable
final class NotesCoordinator {
    private enum Presentation {
        case editor
        case create
        case search
    }

    private let store: NotesStore
    private let settings: AppSettings
    private let appIndex: AppIndex
    private unowned let core: AppCore
    @ObservationIgnored private lazy var windowController = NotesWindowController(coordinator: self)
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var issueTask: Task<Void, Never>?
    @ObservationIgnored private var operationTask: Task<Void, Never>?
    @ObservationIgnored private var operationID = 0
    @ObservationIgnored private var pendingIssue: NotesStore.Issue?
    private var pendingPresentation: Presentation?
    private var enablementGeneration = 0
    private(set) var isSwitcherPresented = false
    private(set) var switcherSelection: NoteID?
    private(set) var switcherFocusRevision = 0
    private(set) var characterCount = 0
    private(set) var formatting = NoteFormatting.plain
    private(set) var isFormattingBarExpanded: Bool
    private var switcherRename = NoteSwitcherRenameState()
    private var presentationGeneration = 0
    private let defaults: UserDefaults
    private(set) var isSidebarVisible: Bool
    private(set) var isAlwaysOnTop: Bool
    private(set) var statsMode: Int
    var sidebarFilter = NoteSidebarFilter.all
    enum Menu { case outline, actions }
    var menu: Menu?
    private var imports: [UUID: Task<Void, Never>] = [:]
    var notesDirectory: URL { store.notesDirectory }
    var pinnedIDs: Set<NoteID> { store.pinnedIDs }
    var availableTags: [String] { store.availableTags }
    var noteCount: Int { store.summaries.count }
    var saveState: NotesStore.SaveState { store.saveState }
    var activeSummary: NoteSummary? { store.summaries.first { $0.id == store.activeID } }
    var headings: [NoteOutlineHeading] { NoteMetadataExtractor(source: store.source).headings }

    @ObservationIgnored private let saveFormattingBarExpanded: @Sendable (Bool) -> Void

    init(
        store: NotesStore,
        settings: AppSettings,
        appIndex: AppIndex,
        core: AppCore,
        defaults: UserDefaults,
        isFormattingBarExpanded: Bool = false,
        saveFormattingBarExpanded: @escaping @Sendable (Bool) -> Void = { _ in }
    ) {
        self.store = store
        self.settings = settings
        self.appIndex = appIndex
        self.core = core
        self.defaults = defaults
        isSidebarVisible = defaults.object(forKey: "notesSidebarVisible") as? Bool ?? true
        isAlwaysOnTop = defaults.object(forKey: "notesAlwaysOnTop") as? Bool ?? true
        statsMode = defaults.integer(forKey: "notesStatsMode") % 3
        self.isFormattingBarExpanded = isFormattingBarExpanded
        self.saveFormattingBarExpanded = saveFormattingBarExpanded
        store.onIssue = { [weak self] issue in self?.present(issue) }
    }

    var editorInput: NoteEditorInput {
        NoteEditorInput(
            id: store.activeID ?? NoteID(rawValue: ""),
            source: store.source,
            epoch: store.editorEpoch)
    }

    var hasActiveNote: Bool { store.activeID != nil }
    /// UTF-16 units, straight off the text storage: the only length TextKit hands back in O(1).
    var characterCountLabel: String {
        String(localized: "\(characterCount) characters")
    }

    var searchQueryBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.store.searchQuery ?? "" },
            set: { [weak self] in self?.store.updateSearchQuery($0) })
    }

    var activeTitle: String { store.activeTitle }
    var rendersMarkdown: Bool { settings.notesRendersMarkdown }
    var showsFormattingBar: Bool { settings.notesShowsFormattingBar }
    var isSearching: Bool { store.isSearching }
    var visibleNotes: [NoteSummary] {
        let matches =
            store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? store.summaries : store.searchResults.map(\.summary)
        return sidebarFilter.apply(to: matches, pins: pinnedIDs)
    }
    var isRenamingSwitcherNote: Bool { switcherRename.isActive }
    var switcherTitleDraftBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.switcherRename.draft ?? "" },
            set: { [weak self] in self?.switcherRename.updateDraft($0) })
    }

    func applyEnabled() {
        enablementGeneration &+= 1
        let generation = enablementGeneration
        appIndex.setCommandsVisible([.showNotes, .createNote, .searchNotes], settings.notesEnabled)
        guard !settings.notesEnabled else { return }
        presentationGeneration &+= 1
        pendingPresentation = nil
        loadTask?.cancel()
        loadTask = nil
        operationTask?.cancel()
        closeSwitcher(focusEditor: false)
        dismissWorkspace()
        windowController.hide(restoreFocus: false)
        Task { [weak self] in
            guard let self else { return }
            _ = await store.flush()
            guard generation == enablementGeneration, !settings.notesEnabled else { return }
            store.stop()
        }
    }

    /// Quit waits on this so the 300 ms autosave debounce cannot swallow the last edit.
    func prepareForTermination() async {
        await store.flush()
    }

    func toggle() {
        if windowController.isVisible {
            hide()
        } else {
            request(.editor)
        }
    }

    func createNote() {
        if !isSidebarVisible { toggleSidebar() }
        sidebarFilter = .all
        request(.create)
    }

    func searchNotes() {
        if windowController.isVisible { openSwitcher() } else { request(.search) }
    }

    func openSwitcher() {
        guard settings.notesEnabled, store.isLoaded else { return }
        menu = nil
        if isSwitcherPresented {
            switcherFocusRevision &+= 1
            return
        }
        isSwitcherPresented = true
        switcherSelection = store.activeID ?? store.summaries.first?.id
        switcherFocusRevision &+= 1
        if !isSidebarVisible { toggleSidebar() }
    }

    func closeSwitcher(focusEditor: Bool = true) {
        guard isSwitcherPresented || !store.searchQuery.isEmpty else { return }
        switcherRename.cancel()
        isSwitcherPresented = false
        switcherSelection = nil
        store.cancelSearch()

        if focusEditor { windowController.focusEditor() }
    }

    func hide() {
        presentationGeneration &+= 1
        pendingPresentation = nil
        closeSwitcher(focusEditor: false)
        dismissWorkspace()
        windowController.hide(restoreFocus: true)
        Task { await store.flush() }
    }

    func handleEscape() {
        if menu != nil {
            menu = nil
        } else if switcherRename.isActive {
            cancelSwitcherRename()
        } else if isSwitcherPresented {
            closeSwitcher()
        } else {
            hide()
        }
    }

    func reconcileSwitcherSelection() {
        let notes = visibleNotes
        guard !notes.isEmpty else {
            switcherSelection = nil
            return
        }
        if let switcherSelection, notes.contains(where: { $0.id == switcherSelection }) { return }
        switcherSelection = notes.first?.id
    }

    func moveSwitcherSelection(by offset: Int) {
        let notes = visibleNotes
        guard !notes.isEmpty else {
            switcherSelection = nil
            return
        }
        guard let current = switcherSelection,
            let index = notes.firstIndex(where: { $0.id == current })
        else {
            switcherSelection = notes[offset < 0 ? notes.count - 1 : 0].id
            return
        }
        switcherSelection = notes[(index + offset + notes.count) % notes.count].id
    }

    func selectSwitcherNote() {
        guard let switcherSelection else { return }
        select(switcherSelection)
    }

    func activateSwitcherNote(_ id: NoteID) {
        switcherRename.cancel()
        select(id)
    }

    /// Renaming edits the filename, so the field starts from that and never from a derived line.
    func beginSwitcherRename(_ summary: NoteSummary) {
        switcherRename.begin(id: summary.id, title: summary.title)
    }

    func commitSwitcherRename() {
        guard let committed = switcherRename.commit() else { return }
        rename(committed.id, to: committed.title)
    }

    func cancelSwitcherRename() {
        guard switcherRename.isActive else { return }
        switcherRename.cancel()
        windowController.focusEditor()
    }

    func select(_ id: NoteID) {
        runOperation { [weak self] generation in
            guard let self else { return }
            let selected = await store.select(id) { [weak self] in
                self?.permitsCompletion(generation) ?? false
            }
            guard selected, settings.notesEnabled, !Task.isCancelled else {
                if !settings.notesEnabled { store.stop() }
                return
            }
            guard permitsCompletion(generation) else { return }
            menu = nil
            closeSwitcher()
            windowController.show(focusEditor: true)
        }
    }

    func rename(_ id: NoteID, to title: String) {
        runOperation { [weak self] generation in
            guard let self else { return }
            let renamedID = await store.rename(id, to: title)
            guard let renamedID, settings.notesEnabled, !Task.isCancelled else {
                if !settings.notesEnabled { store.stop() }
                return
            }
            switcherSelection = renamedID
            if renamedID == store.activeID, permitsCompletion(generation) {
                windowController.show(focusEditor: false)
            }
        }
    }

    func trashSwitcherSelection() {
        guard let id = switcherSelection ?? store.activeID else { return }
        trash(id)
    }

    func handleDeleteShortcut() -> Bool {
        guard !switcherRename.isActive, let id = store.activeID else { return false }
        trash(id)
        return true
    }

    func trash(_ id: NoteID) {
        guard let title = store.summaries.first(where: { $0.id == id })?.displayTitle else { return }
        runOperation { [weak self] generation in
            guard let self else { return }
            let confirmed = await core.confirm(
                title: String(localized: "Move “\(title)” to Trash?"),
                message: String(localized: "You can recover it from the Trash in Finder."),
                symbol: nil,
                confirmTitle: String(localized: "Move to Trash"))
            guard confirmed, settings.notesEnabled, !Task.isCancelled else { return }
            let switcherOrder = visibleNotes.map(\.id)
            let removed = await store.trash(id)
            guard removed, settings.notesEnabled, !Task.isCancelled else {
                if !settings.notesEnabled { store.stop() }
                return
            }
            switcherSelection = NoteSwitcherSelection.replacement(
                afterRemoving: id,
                from: switcherOrder,
                fallback: store.activeID ?? store.summaries.first?.id)
            // Nothing left to browse, so the empty state owns the window rather than a bare list.
            if store.summaries.isEmpty { closeSwitcher(focusEditor: false) }
            guard permitsCompletion(generation) else { return }
            windowController.show(focusEditor: !isSwitcherPresented)
        }
    }

    /// Points Notes at a folder as it is; nothing is moved out of the old one.
    func chooseNotesFolder() {
        guard
            let url = FolderPicker.choose(
                message: String(localized: "Choose the folder your notes are kept in."),
                startingAt: store.notesDirectory)
        else { return }
        settings.notesFolder = AppPaths.contentFolderSetting(for: url, named: "Notes")
    }

    func resetNotesFolder() {
        settings.notesFolder = nil
    }

    func openNotesFolder() {
        guard let fileURL = store.activeFileURL else {
            NSWorkspace.shared.open(store.notesDirectory)
            return
        }
        AppLauncher.showInFinder(fileURL)
    }

    func moveToTopRight() {
        windowController.moveToTopRight()
    }

    func updateSource(_ source: String) {
        store.updateSource(source)
    }

    func updateCharacterCount(_ input: NoteEditorInput, _ count: Int) {
        guard input == editorInput else { return }
        characterCount = count
    }

    /// Id and epoch, not the whole input: comparing a long source on every caret move is not free.
    func updateFormatting(_ input: NoteEditorInput, _ formatting: NoteFormatting) {
        let current = editorInput
        guard input.id == current.id, input.epoch == current.epoch, formatting != self.formatting else {
            return
        }
        self.formatting = formatting
    }

    func format(_ action: NoteEditAction) {
        windowController.format(action)
    }

    func toggleFormattingBar() {
        guard showsFormattingBar else { return }
        // Explicit, because the chord changes this from outside any view's transaction.
        withAnimation(Self.barMotion) { isFormattingBarExpanded.toggle() }
        saveFormattingBarExpanded(isFormattingBarExpanded)
    }

    private static var barMotion: Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil : Theme.MenuMotion.chevronAnimation
    }

    func editorReady(_ textView: NoteTextView) {
        textView.onImageImport = { [weak self] in self?.importImage($0) }
        textView.onImagePreview = { [weak self] path in
            guard let self,
                let url = try? NotesAssetStore(notesDirectory: notesDirectory).validatedAssetURL(path)
            else { return }
            windowController.preview(url)
        }
        textView.onTag = { [weak self] in self?.filter(tag: $0) }
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])
        windowController.editorReady(textView)
    }

    private func request(_ presentation: Presentation) {
        guard settings.notesEnabled else { return }
        pendingPresentation = presentation
        guard loadTask == nil else { return }
        let generation = enablementGeneration
        loadTask = Task { [weak self] in
            guard let self else { return }
            // Create is its own load: the collection it would wait for is the one it adds to.
            let loaded = presentation == .create ? await store.create() : await store.start()
            guard generation == enablementGeneration else {
                if !settings.notesEnabled { store.stop() }
                return
            }
            loadTask = nil
            guard loaded, settings.notesEnabled, !Task.isCancelled else { return }
            // The note this task just made satisfies a create still pending; never make a second.
            if presentation == .create, pendingPresentation == .create {
                pendingPresentation = .editor
            }
            guard let next = pendingPresentation else { return }
            pendingPresentation = nil
            await present(next)
        }
    }

    private func present(_ presentation: Presentation) async {
        switch presentation {
        case .editor:
            menu = nil
            closeSwitcher()
            windowController.show(focusEditor: true)
        case .create:
            let generation = presentationGeneration
            guard await store.create(), settings.notesEnabled, !Task.isCancelled,
                generation == presentationGeneration
            else { return }
            menu = nil
            closeSwitcher()
            windowController.show(focusEditor: true)
        case .search:
            windowController.show(focusEditor: false)
            openSwitcher()
        }
    }

    /// A newer show or hide retires an older operation's right to put what it loaded on screen.
    private func permitsCompletion(_ generation: Int) -> Bool {
        windowController.isVisible && generation == presentationGeneration
    }

    /// One collection operation at a time: a newer request cancels and supersedes an in-flight one.
    private func runOperation(_ body: @escaping @MainActor (Int) async -> Void) {
        operationTask?.cancel()
        operationID &+= 1
        let id = operationID
        let generation = presentationGeneration
        operationTask = Task { [weak self] in
            guard let self else { return }
            await body(generation)
            if self.operationID == id { self.operationTask = nil }
        }
    }

    private func present(_ issue: NotesStore.Issue) {
        guard issueTask == nil else {
            pendingIssue = issue
            return
        }
        issueTask = Task { [weak self] in
            guard let self else { return }
            switch issue {
            case .load(let failure):
                let retry = await core.reportFailure(
                    title: String(localized: "Couldn't Open Note"),
                    message: failure.localizedDescription,
                    symbol: "text.page",
                    recovery: String(localized: "Retry"))
                if retry { _ = await store.reload() }
            case .save(let failure):
                let retry = await core.reportFailure(
                    title: String(localized: "Couldn't Save Note"),
                    message: failure.localizedDescription,
                    symbol: "text.page",
                    recovery: String(localized: "Retry"))
                if retry { await store.retrySave() }
            case .operation(let failure):
                _ = await core.reportFailure(
                    title: String(localized: "Couldn't Update Note"),
                    message: failure.localizedDescription,
                    symbol: "text.page",
                    recovery: nil)
            }
            issueTask = nil
            if let pendingIssue {
                self.pendingIssue = nil
                present(pendingIssue)
            }
        }
    }
}

extension NotesCoordinator {
    func toggleMenu(_ requested: Menu) { menu = menu == requested ? nil : requested }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        defaults.set(isSidebarVisible, forKey: "notesSidebarVisible")
        if !isSidebarVisible { closeSwitcher() }
        windowController.resizeSidebar()
    }

    func toggleFloating() {
        isAlwaysOnTop.toggle()
        defaults.set(isAlwaysOnTop, forKey: "notesAlwaysOnTop")
        windowController.updateLevel()
    }

    func togglePin(_ id: NoteID) { store.togglePin(id) }

    func cycleStats() {
        statsMode = (statsMode + 1) % 3
        defaults.set(statsMode, forKey: "notesStatsMode")
    }

    var statsLabel: String {
        switch statsMode {
        case 1:
            var words = 0
            store.source.enumerateSubstrings(
                in: store.source.startIndex..., options: [.byWords, .substringNotRequired]
            ) { _, _, _, _ in
                words += 1
            }
            return String(localized: "\(words) words · \(max(1, (words + 199) / 200)) min")
        case 2:
            return String(
                localized:
                    "\(activeSummary?.totalTaskCount ?? 0) tasks · \(activeSummary?.imageCount ?? 0) images")
        default: return characterCountLabel
        }
    }

    func filter(tag: String) {
        if !isSidebarVisible { toggleSidebar() }
        sidebarFilter = sidebarFilter == .tag(tag) ? .all : .tag(tag)
    }

    func jump(to heading: NoteOutlineHeading) {
        menu = nil
        windowController.jump(to: heading.range)
    }

    func copyNote(plain: Bool) {
        menu = nil
        var text = store.source
        if plain {
            let markdown = NoteMarkdownParser.parse(text)
            let source = text as NSString
            text = markdown.lines.map { line in
                if case .image(let alt, _) = line.kind { return alt }
                if case .code = line.kind { return source.substring(with: line.contentRange) }
                return NoteTitle.visibleText(of: line, in: markdown, text: source)
            }.joined(separator: "\n")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        core.showMessage(String(localized: "Copied"))
    }

    func toggleRaw() {
        settings.notesRendersMarkdown.toggle()
    }

    func pickImage() {
        menu = nil
        let id = store.activeID
        let epoch = store.editorEpoch
        windowController.pickImage { [weak self] url in
            guard let self, settings.notesEnabled, store.activeID == id, store.editorEpoch == epoch else {
                return
            }
            importImage(.file(url))
        }
    }

    private func importImage(_ input: NotesAssetStore.Input) {
        guard let id = store.activeID, rendersMarkdown else { return }
        let epoch = store.editorEpoch
        let directory = notesDirectory
        let token = UUID()
        imports[token] = Task { [weak self] in
            guard let self else { return }
            defer { imports.removeValue(forKey: token) }
            do {
                let path = try await NotesAssetStore(notesDirectory: directory).importImage(input)
                guard !Task.isCancelled, settings.notesEnabled, windowController.isVisible,
                    directory == notesDirectory, id == store.activeID, epoch == store.editorEpoch,
                    rendersMarkdown
                else { return }
                let alt = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                format(.insertImage(alt: alt, path: path))
            } catch {
                if !Task.isCancelled { core.showMessage(error.localizedDescription, tone: .danger) }
            }
        }
    }

    func cleanImages() {
        menu = nil
        let directory = notesDirectory
        runOperation { [weak self] generation in
            guard let self,
                await core.confirm(
                    title: String(localized: "Clean unused images?"),
                    message: String(localized: "Unreferenced imported images will move to the Trash."),
                    symbol: "trash", confirmTitle: String(localized: "Move to Trash")),
                directory == notesDirectory, permitsCompletion(generation), imports.isEmpty,
                await store.flush()
            else { return }
            let assets = NotesAssetStore(notesDirectory: directory)
            do {
                let files = try await Task.detached(priority: .utility) { try assets.orphanedAssets() }.value
                guard !Task.isCancelled, directory == notesDirectory, permitsCompletion(generation),
                    imports.isEmpty, !store.isDirty
                else { return }
                for file in files where !store.source.contains(file.lastPathComponent) {
                    let url = try assets.validatedAssetURL("assets/" + file.lastPathComponent)
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
                core.showMessage(String(localized: "\(files.count) unused images removed"))
            } catch { core.showMessage(error.localizedDescription, tone: .danger) }
        }
    }

    func resolveConflict(keepDraft: Bool) {
        runOperation { [weak self] _ in
            if keepDraft {
                await self?.store.resolveConflictKeepDraft()
            } else {
                await self?.store.resolveConflictLoadDisk()
            }
        }
    }

    private func dismissWorkspace() {
        menu = nil
        switcherRename.cancel()
        for task in imports.values { task.cancel() }
        imports.removeAll()
    }
}
