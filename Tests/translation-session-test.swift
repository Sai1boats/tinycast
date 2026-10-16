import AppKit

@main
@MainActor
struct TranslationSessionTests {
    static func main() async {
        let core = AppCore()
        let coordinator = TranslationCoordinator(core: core, palette: PaletteCoordinator(), injector: TextInjector())
        coordinator.show(selection: false)
        await waitUntil { !coordinator.isLoading }
        precondition(!coordinator.isLoading && !coordinator.showsSettings)
        coordinator.text = "first"
        coordinator.translate()
        await waitUntil { BaiduTranslationService.pending.count == 1 }
        precondition(BaiduTranslationService.pending.count == 1)
        coordinator.text = "second"
        coordinator.translate()
        await waitUntil { BaiduTranslationService.pending.count == 2 }
        BaiduTranslationService.finish(index: 0, text: "stale")
        await waitUntil { BaiduTranslationService.completed == 1 }
        precondition(coordinator.result == nil && coordinator.isTranslating)
        BaiduTranslationService.finish(index: 1, text: "current")
        await waitUntil { BaiduTranslationService.completed == 2 }
        precondition(coordinator.result?.text == "current" && !coordinator.isTranslating)
        coordinator.translate()
        await waitUntil { BaiduTranslationService.pending.count == 3 }
        coordinator.destination = "jp"
        BaiduTranslationService.finish(index: 2, text: "wrong language")
        await waitUntil { BaiduTranslationService.completed == 3 }
        precondition(coordinator.result == nil && !coordinator.isTranslating)
        coordinator.translate()
        await waitUntil { BaiduTranslationService.pending.count == 4 }
        coordinator.close()
        coordinator.show(selection: false)
        await waitUntil { !coordinator.isLoading }
        BaiduTranslationService.finish(index: 3, text: "closed session")
        await waitUntil { BaiduTranslationService.completed == 4 }
        precondition(coordinator.result == nil)
        coordinator.browseHistory(older: true)
        precondition(coordinator.result?.text == "current")
        coordinator.swapLanguages()
        precondition(coordinator.text == "current" && coordinator.source == "zh" && coordinator.destination == "en")
        precondition(coordinator.result == nil)
        coordinator.show(selection: true)
        await waitUntil { QuickActionRunner.pending != nil }
        precondition(coordinator.isReadingSelection)
        coordinator.text = "typed while reading"
        QuickActionRunner.pending?.resume(returning: "late selection")
        QuickActionRunner.pending = nil
        await waitUntil { !coordinator.isReadingSelection }
        precondition(coordinator.text == "typed while reading" && !coordinator.isReadingSelection)
        await testFallback(coordinator)
        coordinator.appID = "new fixture"
        coordinator.secret = "new fixture"
        coordinator.saveCredentials()
        await waitUntil { BaiduTranslationService.pendingSave != nil }
        coordinator.show(selection: false)
        precondition(coordinator.isSaving)
        BaiduTranslationService.pendingSave?.resume()
        BaiduTranslationService.pendingSave = nil
        await waitUntil { !coordinator.isSaving }
        precondition(!coordinator.showsSettings)
        coordinator.close()
        print("Translation cancellation, late completion, language changes, session identity and selection races passed")
    }

    static func testFallback(_ coordinator: TranslationCoordinator) async {
        coordinator.show(selection: false)
        await waitUntil { !coordinator.isLoading }
        BaiduTranslationService.failure = BaiduTranslation.Failure.unavailable
        coordinator.text = "network down"
        coordinator.translate()
        await waitUntil { AppleTranslationService.pending != nil }
        precondition(coordinator.isTranslating && coordinator.result == nil)
        AppleTranslationService.finish(text: "苹果")
        await waitUntil { !coordinator.isTranslating }
        precondition(coordinator.result?.provider == .apple && coordinator.result?.text == "苹果")
        precondition(!coordinator.fallbackReason.isEmpty, "a fallback says why Baidu did not answer")
        BaiduTranslationService.failure = BaiduTranslation.Failure.unavailable
        coordinator.text = "edited during fallback"
        coordinator.translate()
        await waitUntil { AppleTranslationService.pending != nil }
        coordinator.text = "newer"
        AppleTranslationService.finish(text: "stale apple")
        await Task.yield()
        precondition(coordinator.result == nil && coordinator.fallbackReason.isEmpty,
                     "a late Apple result never lands on edited text")
        BaiduTranslationService.failure = nil
        coordinator.close()
        BaiduTranslationService.stored = nil
        coordinator.show(selection: false)
        await waitUntil { !coordinator.isLoading }
        precondition(!coordinator.showsSettings && !coordinator.hasCredentials,
                     "missing credentials no longer block the panel")
        let baiduCalls = BaiduTranslationService.pending.count
        coordinator.text = "no credentials"
        coordinator.translate()
        await waitUntil { AppleTranslationService.pending != nil }
        precondition(BaiduTranslationService.pending.count == baiduCalls, "Baidu is skipped without credentials")
        AppleTranslationService.finish(text: "无凭据")
        await waitUntil { !coordinator.isTranslating }
        precondition(coordinator.result?.provider == .apple)
        coordinator.text = " "
        coordinator.translate()
        precondition(AppleTranslationService.pending == nil && !coordinator.message.isEmpty,
                     "empty input is reported, not handed to Apple")
        coordinator.close()
        BaiduTranslationService.stored = BaiduTranslationService.Credentials(appID: "fixture", secret: "fixture")
    }

    static func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            precondition(ContinuousClock.now < deadline, "Timed out waiting for the coordinator")
            await Task.yield()
        }
    }
}

@MainActor
final class AppCore {
    enum Tone { case danger }
    func showMessage(_ message: String, tone: Tone? = nil) {}
}

@MainActor
final class PaletteCoordinator {
    var targetApp: NSRunningApplication? { nil }
    func hidePalette(restoreFocus: Bool) {}
}

@MainActor
final class TextInjector {
    func replaceSelection(
        with text: String, in target: NSRunningApplication,
        onDelivered: @escaping @MainActor () -> Void, onFailed: @escaping @MainActor () -> Void
    ) { preconditionFailure("No system input is allowed in this harness") }
}

@MainActor
final class TranslationPanelController {
    func show(_ coordinator: TranslationCoordinator) {}
    func setExpanded(_ expanded: Bool) -> Bool { expanded }
    func dismiss() {}
    func focus() {}
}

@MainActor
enum Paster {
    static func copyPlainText(_ text: String) { preconditionFailure("No shared clipboard writes") }
}

enum Permissions {
    static func ensureAccessibility() -> Bool { false }
}

@MainActor
enum QuickActionRunner {
    static var pending: CheckedContinuation<String, any Error>?
    static func selection(in target: NSRunningApplication?, using injector: TextInjector) async throws -> String {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
}

@MainActor
enum BaiduTranslationService {
    struct Credentials {
        let appID: String
        let secret: String
    }
    static var pending: [CheckedContinuation<TranslationResult, any Error>] = []
    static var completed = 0
    static var failure: (any Error)?
    static var stored: Credentials? = Credentials(appID: "fixture", secret: "fixture")
    static var pendingSave: CheckedContinuation<Void, any Error>?
    static func credentials() async throws -> Credentials? { stored }
    static func save(_ credentials: Credentials) async throws {
        try await withCheckedThrowingContinuation { pendingSave = $0 }
    }
    static func translate(
        text: String, source: String, target: String, credentials: Credentials
    ) async throws -> TranslationResult {
        if let failure { throw failure }
        let result = try await withCheckedThrowingContinuation { pending.append($0) }
        completed += 1
        return result
    }
    static func finish(index: Int, text: String) {
        pending[index].resume(returning: TranslationResult(
            original: "second", paragraphs: [.init(source: "second", text: text)], source: "en", target: "zh",
            provider: .baidu))
    }
}

@MainActor
enum AppleTranslationService {
    enum Failure: String, Error { case unsupportedLanguage }
    static var pending: CheckedContinuation<TranslationResult, any Error>?
    static func translate(text: String, source: String, target: String) async throws -> TranslationResult {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    static func finish(text: String) {
        pending?.resume(returning: TranslationResult(
            original: "apple", paragraphs: [.init(source: "apple", text: text)], source: "en", target: "zh",
            provider: .apple))
        pending = nil
    }
}

enum Theme {
    enum Size {
        static let translationTextDefault: CGFloat = 15
        static let translationTextMinimum: CGFloat = 12
        static let translationTextMaximum: CGFloat = 26
    }
}
