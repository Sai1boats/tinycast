import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class UtilityCoordinator {
    private unowned let core: AppCore
    let rates: CurrencyRateStore
    @ObservationIgnored private var windows: [UtilityTool: AppWindowController] = [:]
    @ObservationIgnored private var developerSessions: [UtilityTool: DeveloperToolSession] = [:]
    @ObservationIgnored private var jsonTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    private var generation = 0
    private var presentation = UUID()
    /// The clipboard change each window is offering to load; the text itself is never kept.
    private(set) var clipboardSuggestions: [UtilityTool: Int] = [:]
    @ObservationIgnored private var declinedClipboard: [UtilityTool: Int] = [:]
    var jsonInput = "" { didSet { if oldValue != jsonInput { cancelJSON() } } }
    private(set) var jsonOutput = ""
    private(set) var jsonError = ""
    private(set) var jsonBusy = false
    var timestampInput = "" { didSet { timestampResult = nil; timestampError = "" } }
    var dateInput = "" { didSet { timestampResult = nil; timestampError = "" } }
    var timestampUnit = TimestampConverter.Unit.automatic { didSet { timestampResult = nil; timestampError = "" } }
    var timeZoneID = TimeZone.current.identifier { didSet { timestampResult = nil; timestampError = "" } }
    private(set) var timestampResult: TimestampConverter.Result?
    private(set) var timestampError = ""
    var currencyInput = ""
    var sourceCurrency = "CNY"
    var targetCurrency = ""

    init(core: AppCore, rates: CurrencyRateStore) {
        self.core = core
        self.rates = rates
    }

    func show(_ tool: UtilityTool) {
        core.paletteCoordinator.hidePalette(restoreFocus: false)
        let session = tool.isDeveloperTool ? developerSession(for: tool) : nil
        if windows[tool] == nil {
            windows[tool] = AppWindowController(
                title: NSLocalizedString(tool.title, comment: "Utility window"),
                contentSize: Theme.Size.utilityFocusWindow, minimumSize: Theme.Size.utilityFocusMinimum,
                resizable: true, autosaveName: "UtilityFocus-" + tool.rawValue,
                activation: core.activationPolicy, closesOnEscape: true)
            windows[tool]?.onClose = { [weak self] in
                self?.disappear(tool)
                self?.developerSessions.removeValue(forKey: tool)
                self?.clipboardSuggestions[tool] = nil
            }
            windows[tool]?.onBecomeKey = { [weak self] in self?.checkClipboard(for: tool) }
        }
        windows[tool]?.show(chrome: UtilityWindowChrome()) {
            UtilityWindowView(tool: tool, developerSession: session).environment(self)
        }
        checkClipboard(for: tool)
    }

    /// Opens the tool already working on text the launcher recognised as its input.
    func show(_ tool: UtilityTool, input: String) {
        show(tool)
        load(input, into: tool)
        checkClipboard(for: tool)
    }

    func checkClipboard(for tool: UtilityTool) {
        guard UtilityInputDetector.detectableTools.contains(tool) else { return }
        let change = UtilityClipboard.changeCount
        guard declinedClipboard[tool] != change, let text = UtilityClipboard.text(),
            UtilityInputDetector.tool(for: text) == tool,
            text.trimmingCharacters(in: .whitespacesAndNewlines) != input(of: tool)
        else {
            clipboardSuggestions[tool] = nil
            return
        }
        clipboardSuggestions[tool] = change
    }

    func acceptClipboardSuggestion(for tool: UtilityTool) {
        declinedClipboard[tool] = UtilityClipboard.changeCount
        clipboardSuggestions[tool] = nil
        guard let text = UtilityClipboard.text(), UtilityInputDetector.tool(for: text) == tool else {
            core.showMessage(String(localized: "The clipboard changed. Nothing was loaded."), tone: .danger)
            return
        }
        load(text, into: tool)
    }

    func declineClipboardSuggestion(for tool: UtilityTool) {
        declinedClipboard[tool] = clipboardSuggestions[tool]
        clipboardSuggestions[tool] = nil
    }

    private func load(_ text: String, into tool: UtilityTool) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tool {
        case .json:
            jsonInput = value
            runJSON(.format)
        case .timestamp:
            timestampInput = value
            convertTimestamp(fromDate: false)
        case .jwt:
            developerSession(for: .jwt).input = value
            inspectJWT()
        case .base64:
            let session = developerSession(for: .base64)
            if let alphabet = UtilityInputDetector.base64Alphabet(for: value) { session.base64Alphabet = alphabet }
            session.input = value
            runEncoding(.base64, decoding: true)
        case .urlCodec:
            developerSession(for: .urlCodec).input = value
            runEncoding(.urlCodec, decoding: true)
        case .currency, .uuid, .hash, .textDiff:
            break
        }
    }

    private func input(of tool: UtilityTool) -> String {
        let text = switch tool {
        case .json: jsonInput
        case .timestamp: timestampInput
        default: developerSessions[tool]?.input ?? ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func disappear(_ tool: UtilityTool) {
        developerSessions[tool]?.cancel()
        if tool == .json { cancelJSON() }
        if tool == .currency {
            presentation = UUID()
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    func close(_ tool: UtilityTool) {
        disappear(tool)
        windows[tool]?.close()
    }

    func close() {
        for tool in UtilityTool.allCases { close(tool) }
    }

    func developerSession(for tool: UtilityTool) -> DeveloperToolSession {
        if let session = developerSessions[tool] { return session }
        let session = DeveloperToolSession()
        developerSessions[tool] = session
        return session
    }

    func runEncoding(_ tool: UtilityTool, decoding: Bool) {
        let session = developerSession(for: tool)
        switch tool {
        case .urlCodec: session.run(decoding ? .decodeURL(session.urlMode) : .encodeURL(session.urlMode))
        case .base64: session.run(decoding ? .decodeBase64(session.base64Alphabet) : .encodeBase64(session.base64Alphabet))
        default: break
        }
    }

    func generateUUIDs() { developerSession(for: .uuid).generateUUIDs() }

    func computeHash() {
        let session = developerSession(for: .hash)
        session.run(.hash(session.hashAlgorithm))
    }

    func inspectJWT() { developerSession(for: .jwt).run(.jwt(Date())) }

    func compareText() {
        let session = developerSession(for: .textDiff)
        session.run(.diff(session.comparisonInput))
    }

    func swapComparisonTexts() {
        let session = developerSession(for: .textDiff)
        let original = session.input
        session.input = session.comparisonInput
        session.comparisonInput = original
    }

    func readClipboard(into session: DeveloperToolSession, comparison: Bool = false) {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            session.clipboardUnavailable()
            return
        }
        if comparison { session.comparisonInput = text } else { session.input = text }
        if let tool = developerSessions.first(where: { $0.value === session })?.key {
            clipboardSuggestions[tool] = nil
        }
    }

    func runJSON(_ operation: JSONTool.Operation) {
        cancelJSON()
        let version = generation
        let input = jsonInput
        jsonBusy = true
        jsonTask = Task { [weak self] in
            do {
                let output = try await JSONTool.transform(input, operation: operation)
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.jsonOutput = output
                self.jsonBusy = false
                self.jsonTask = nil
            } catch {
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.jsonBusy = false
                self.jsonTask = nil
                self.jsonError = self.jsonMessage(error)
            }
        }
    }

    func cancelJSON() {
        generation += 1
        jsonTask?.cancel()
        jsonTask = nil
        jsonBusy = false
        jsonOutput = ""
        jsonError = ""
    }

    func readJSONClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            jsonError = String(localized: "The clipboard contains no text.")
            return
        }
        jsonInput = text
        clipboardSuggestions[.json] = nil
    }

    func convertTimestamp(fromDate: Bool) {
        guard let zone = TimeZone(identifier: timeZoneID) else { return }
        timestampResult = nil
        timestampError = ""
        do {
            timestampResult = try fromDate
                ? TimestampConverter.fromDate(dateInput, timeZone: zone)
                : TimestampConverter.fromTimestamp(timestampInput, unit: timestampUnit, timeZone: zone)
        } catch TimestampConverter.Failure.ambiguousDate {
            timestampError = String(localized: "This local time occurs twice during a clock change. Use UTC to disambiguate.")
        } catch TimestampConverter.Failure.invalidDate {
            timestampError = String(localized: "Enter a valid date as yyyy-MM-dd HH:mm:ss or yyyy-MM-dd HH:mm:ss.SSS.")
        } catch {
            timestampError = String(localized: "Enter seconds or integer milliseconds within years 0001–9999.")
        }
    }

    func useNow() {
        guard let zone = TimeZone(identifier: timeZoneID),
            let result = try? TimestampConverter.result(for: Date(), timeZone: zone) else { return }
        timestampInput = timestampUnit == .seconds ? result.seconds : result.milliseconds
        dateInput = result.localDate
        timestampResult = result
        timestampError = ""
    }

    var currencyCodes: [String] {
        let known = rates.rates.map { Array($0.rates.keys) + [$0.base] } ?? []
        return Set(known + [sourceCurrency, "USD", "CNY", "EUR", "GBP", "JPY", "HKD"])
            .sorted()
    }

    var currencyQuery: CurrencyQuery? {
        try? CurrencyQuery.parse(currencyInput, defaultSource: sourceCurrency,
                                 target: targetCurrency.isEmpty ? nil : targetCurrency)
    }

    var currencyTargets: [String] {
        guard let query = currencyQuery else { return [] }
        return query.target.map { [$0] } ?? CurrencyQuery.popular.filter { $0 != query.source }
    }

    func currencyValue(for code: String) -> String? {
        guard let query = currencyQuery else { return nil }
        return try? CurrencyConversion.convert(query.amount, from: query.source, to: code, rates: rates.rates)
    }

    var currencyMessage: String {
        guard !currencyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard currencyQuery != nil else {
            return String(localized: "Enter an amount and currency, such as $200 or 100 CNY to USD.")
        }
        return ""
    }

    func refreshRates() {
        guard refreshTask == nil else { return }
        let session = presentation
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let success = await self.rates.refresh()
            guard !Task.isCancelled, self.presentation == session else { return }
            self.refreshTask = nil
            if !success {
                self.core.showMessage(
                    String(localized: "Some rates could not be refreshed. Showing the available data."), tone: .danger)
            }
        }
    }

    func copy(_ text: String) {
        guard !text.isEmpty else { return }
        Paster.copyPlainText(text)
        core.showMessage(String(localized: "Copied"))
    }

    private func jsonMessage(_ error: Error) -> String {
        switch error {
        case JSONTool.Failure.invalid(let offset): String(localized: "Invalid JSON near byte \(offset).")
        case JSONTool.Failure.tooLarge:
            String(localized: "JSON is too large: maximum 1 MB input and 4 MB formatted output.")
        case JSONTool.Failure.nesting: String(localized: "JSON nesting exceeds 128 levels.")
        case JSONTool.Failure.notEscaped:
            String(localized: "Enter a JSON string literal or escaped text such as {\\\"key\\\":1}.")
        default: error.localizedDescription
        }
    }
}
