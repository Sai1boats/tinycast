import AppKit
import Observation

@MainActor
@Observable
final class TranslationCoordinator {
    private unowned let core: AppCore
    private let palette: PaletteCoordinator
    private let injector: TextInjector
    private let panels = TranslationPanelController()
    private var target: NSRunningApplication?
    private var credentials: BaiduTranslationService.Credentials?
    private var history = TranslationHistory()
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var saving: Task<Void, Never>?
    private var generation = 0
    private var session = UUID()

    var text = "" { didSet { if oldValue != text { invalidate() } } }
    var source = "auto" { didSet { if oldValue != source { invalidate() } } }
    var destination = "auto" { didSet { if oldValue != destination { invalidate() } } }
    private(set) var result: BaiduTranslation?
    private(set) var isReadingSelection = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isTranslating = false
    private(set) var message = ""
    var showsSettings = false
    var appID = ""
    var secret = ""
    var isPinned = false

    init(core: AppCore, palette: PaletteCoordinator, injector: TextInjector) {
        self.core = core
        self.palette = palette
        self.injector = injector
    }

    func show(selection: Bool) {
        guard !isSaving else { panels.focus(); return }
        let candidate = palette.targetApp
        if candidate?.bundleIdentifier != Bundle.main.bundleIdentifier { target = candidate }
        palette.hidePalette(restoreFocus: false)
        isLoading = true
        isReadingSelection = selection
        panels.show(self)
        loading?.cancel()
        session = UUID()
        let currentSession = session
        invalidate()
        let version = generation
        let capturedTarget = target
        isLoading = true
        loading = Task { [weak self] in
            defer {
                if let self, self.session == currentSession {
                    self.isLoading = false
                    self.isReadingSelection = false
                    self.loading = nil
                }
            }
            do {
                let stored = try await BaiduTranslationService.credentials()
                guard let self, !Task.isCancelled, self.session == currentSession else { return }
                self.credentials = stored
                self.appID = stored?.appID ?? ""
                self.secret = stored?.secret ?? ""
                self.isLoading = false
                self.showsSettings = stored == nil
                guard selection, self.generation == version else {
                    self.isReadingSelection = false
                    return
                }
                let selected = try await QuickActionRunner.selection(in: capturedTarget, using: self.injector)
                guard !Task.isCancelled, self.session == currentSession, self.generation == version else { return }
                self.isReadingSelection = false
                self.panels.focus()
                self.text = selected
                if stored != nil { self.translate() }
            } catch {
                guard let self, !Task.isCancelled, self.session == currentSession else { return }
                self.isLoading = false
                self.isReadingSelection = false
                self.panels.focus()
                if self.generation == version { self.report(error) }
            }
        }
    }

    func translate() {
        guard let credentials else { showsSettings = true; return }
        invalidate()
        let version = generation
        let input = text
        let from = source
        let to = destination
        isTranslating = true
        running = Task { [weak self] in
            do {
                let translated = try await BaiduTranslationService.translate(
                    text: input, source: from, target: to, credentials: credentials)
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.result = translated
                self.history.append(translated)
                self.isTranslating = false
                self.running = nil
            } catch {
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.isTranslating = false
                self.running = nil
                self.report(error)
            }
        }
    }

    func saveCredentials() {
        guard !isSaving else { return }
        let value = BaiduTranslationService.Credentials(
            appID: appID.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines))
        let currentSession = session
        invalidate()
        isSaving = true
        saving = Task { [weak self] in
            do {
                try await BaiduTranslationService.save(value)
                guard let self, !Task.isCancelled, self.session == currentSession else { return }
                self.credentials = value
                self.isSaving = false
                self.showsSettings = false
                self.message = ""
            } catch {
                guard let self, !Task.isCancelled, self.session == currentSession else { return }
                self.isSaving = false
                self.report(error)
            }
        }
    }

    func swapLanguages() {
        let from = result?.source ?? source
        let to = result?.target ?? destination
        guard from != "auto", to != "auto", TranslationLanguage.codes.contains(from),
            TranslationLanguage.codes.contains(to)
        else {
            message = String(localized: "Translate once or choose both languages before swapping.")
            return
        }
        let translated = result?.text
        source = to
        destination = from
        if let translated { text = translated }
    }

    func browseHistory(older: Bool) {
        guard let entry = history.move(older: older) else { return }
        invalidate()
        text = entry.original
        source = entry.source
        destination = entry.target
        result = entry
    }

    func readClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            message = String(localized: "The clipboard contains no text.")
            return
        }
        text = value
    }

    func copy(_ text: String) {
        guard !text.isEmpty else { return }
        Paster.copyPlainText(text)
        core.showMessage(String(localized: "Copied"))
    }

    func pasteResult() {
        guard let result, !result.text.isEmpty, let target, !target.isTerminated,
            target.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            message = String(localized: "No destination app. Copy the translation instead.")
            return
        }
        guard Permissions.ensureAccessibility() else { return }
        let output = result.text
        close()
        injector.replaceSelection(
            with: output, in: target,
            onDelivered: {},
            onFailed: { [weak self] in
                Paster.copyPlainText(output)
                self?.core.showMessage(String(localized: "Could not paste. Translation copied instead."), tone: .danger)
            })
    }

    func close() {
        session = UUID()
        invalidate()
        loading?.cancel()
        saving?.cancel()
        loading = nil
        saving = nil
        isLoading = false
        isReadingSelection = false
        isSaving = false
        target = nil
        secret = ""
        panels.dismiss()
    }

    private func invalidate() {
        generation += 1
        running?.cancel()
        running = nil
        isTranslating = false
        result = nil
        message = ""
    }

    private func report(_ error: Error) {
        if let failure = error as? BaiduTranslation.Failure {
            message = NSLocalizedString(failure.rawValue, comment: "Translation error")
        } else {
            message = error.localizedDescription
        }
        core.showMessage(message, tone: .danger)
    }
}
