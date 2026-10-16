import AppKit
import Observation

@MainActor
@Observable
final class TranslationCoordinator {
    struct Progress: Equatable {
        let completed: Int
        let total: Int
    }

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
    private(set) var result: TranslationResult?
    /// The chunks translated so far while a long text is still in flight.
    private(set) var partial: TranslationResult?
    private(set) var progress: Progress?
    /// Why Apple answered instead of Baidu; empty when Baidu did.
    private(set) var fallbackReason = ""
    private(set) var isReadingSelection = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isTranslating = false
    private(set) var message = ""
    var showsSettings = false
    var showsBilingual = false
    var textSize = Theme.Size.translationTextDefault
    var appID = ""
    var secret = ""
    var isPinned = false

    private(set) var isExpanded = false

    var hasCredentials: Bool { credentials != nil }
    var displayedResult: TranslationResult? { result ?? partial }

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
                guard selection, self.generation == version else {
                    self.isReadingSelection = false
                    return
                }
                let selected = try await QuickActionRunner.selection(in: capturedTarget, using: self.injector)
                guard !Task.isCancelled, self.session == currentSession, self.generation == version else { return }
                self.isReadingSelection = false
                self.panels.focus()
                self.text = selected
                self.translate()
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
        invalidate()
        let version = generation
        let input = text
        let from = source
        let to = destination
        let stored = credentials
        do {
            try BaiduTranslation.validateDocument(input, source: from, target: to)
        } catch BaiduTranslation.Failure.tooLong {
            return translateWithApple(input, from: from, to: to, reason: BaiduTranslation.Failure.tooLong, version: version)
        } catch {
            return report(error)
        }
        guard let stored else {
            return translateWithApple(
                input, from: from, to: to, reason: BaiduTranslation.Failure.credentials, version: version)
        }
        let chunks = TranslationChunks.split(input)
        isTranslating = true
        progress = Progress(completed: 0, total: chunks.count)
        running = Task { [weak self] in
            do {
                var combined: TranslationResult?
                for (index, chunk) in chunks.enumerated() {
                    if index > 0 { try await Task.sleep(for: Self.chunkPacing) }
                    let piece = try await BaiduTranslationService.translate(
                        text: chunk, source: combined?.source ?? from, target: combined?.target ?? to,
                        credentials: stored)
                    guard let self, !Task.isCancelled, self.generation == version else { return }
                    combined = combined.map { $0.appending(piece) } ?? piece
                    self.partial = combined
                    self.progress = Progress(completed: index + 1, total: chunks.count)
                }
                guard let self, let combined else { return }
                self.finish(combined)
            } catch {
                guard let self, !Task.isCancelled, self.generation == version else { return }
                guard BaiduTranslation.allowsFallback(after: error) else {
                    self.stopTranslating()
                    return self.report(error)
                }
                self.translateWithApple(input, from: from, to: to, reason: error, version: version)
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

    func adjustTextSize(by step: CGFloat) {
        textSize = min(max(textSize + step, Theme.Size.translationTextMinimum), Theme.Size.translationTextMaximum)
    }

    func toggleExpanded() { isExpanded = panels.setExpanded(!isExpanded) }

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
        isExpanded = false
        panels.dismiss()
    }

    /// Baidu's standard tier answers one request a second; a long text waits its turn per chunk.
    private static let chunkPacing = Duration.milliseconds(1100)

    private func translateWithApple(
        _ input: String, from: String, to: String, reason: any Error, version: Int
    ) {
        let reasonText = describe(reason)
        isTranslating = true
        partial = nil
        progress = nil
        running = Task { [weak self] in
            do {
                let translated = try await AppleTranslationService.translate(text: input, source: from, target: to)
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.fallbackReason = reasonText
                self.finish(translated)
            } catch {
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.stopTranslating()
                let detail = self.describe(error)
                self.message = reasonText + "\n" + String(localized: "Apple Translation: \(detail)")
                self.core.showMessage(self.message, tone: .danger)
            }
        }
    }

    private func finish(_ translated: TranslationResult) {
        result = translated
        history.append(translated)
        stopTranslating()
    }

    private func stopTranslating() {
        isTranslating = false
        partial = nil
        progress = nil
        running = nil
    }

    private func invalidate() {
        generation += 1
        running?.cancel()
        stopTranslating()
        result = nil
        fallbackReason = ""
        message = ""
    }

    private func describe(_ error: any Error) -> String {
        if let failure = error as? BaiduTranslation.Failure {
            return NSLocalizedString(failure.rawValue, comment: "Translation error")
        }
        if let failure = error as? AppleTranslationService.Failure {
            return NSLocalizedString(failure.rawValue, comment: "Translation error")
        }
        return error.localizedDescription
    }

    private func report(_ error: any Error) {
        message = describe(error)
        core.showMessage(message, tone: .danger)
    }
}
