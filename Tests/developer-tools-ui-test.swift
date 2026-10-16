import AppKit
import Observation
import SwiftUI

@main
@MainActor
struct DeveloperToolsUITests {
    static func main() async throws {
        _ = NSApplication.shared
        let core = AppCore()
        let coordinator = UtilityCoordinator(core: core, rates: CurrencyRateStore())
        let tools = UtilityTool.allCases
        for tool in tools {
            coordinator.show(tool)
            let title = NSLocalizedString(tool.title, comment: "Utility title")
            guard let window = NSApp.windows.first(where: { $0.title == title }),
                let root = window.contentView else { preconditionFailure("Missing tool window") }
            window.appearance = NSAppearance(named: .darkAqua)
            try await Task.sleep(for: .milliseconds(30))
            root.layoutSubtreeIfNeeded()
            let expected = switch tool {
            case .json, .urlCodec, .base64, .hash: 2
            case .uuid: 1
            case .jwt, .textDiff: 3
            default: 0
            }
            precondition(editors(in: root).count == expected, "Native editors mount for \(tool)")
            try await populate(coordinator, tool: tool)
            for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                window.appearance = NSAppearance(named: appearance)
                let sizes = [("default", Theme.Size.utilityFocusWindow), ("minimum", Theme.Size.utilityFocusMinimum)]
                for (sizeName, size) in sizes {
                    window.setContentSize(size)
                    try await Task.sleep(for: .milliseconds(30))
                    root.layoutSubtreeIfNeeded()
                    let frames = scrollViews(in: root).map { $0.convert($0.bounds, to: root) }
                    for frame in frames {
                        precondition(frame.width > 0 && frame.height > 0, "Editor remains visible at minimum size")
                        precondition(root.bounds.insetBy(dx: -1, dy: -1).contains(frame), "Editor stays inside the window")
                    }
                    checkAlignment(frames, tool: tool, width: root.bounds.width)
                    try snapshot(root, name: tool.rawValue + "-" + name + "-" + sizeName)
                    if tool == .timestamp || tool == .currency { checkFields(root, tool: tool) }
                }
            }
            if tool == .textDiff { try await diffRendering(coordinator, root: root) }
            coordinator.close(tool)
            precondition(!core.activationPolicy.hasOpenWindows)
            print("\(tool.title): \(expected) native editors fit the minimum window")
        }
        try await lifecycle(coordinator)
        print("Nine focused windows, aligned editors/fields, both appearances, lifecycle and diff colors passed")
    }

    static func checkAlignment(_ frames: [NSRect], tool: UtilityTool, width: CGFloat) {
        guard !frames.isEmpty else { return }
        let leading = frames.map(\.minX).min() ?? 0
        let trailing = frames.map(\.maxX).max() ?? 0
        precondition(abs(leading - Theme.Spacing.xxl) < 1, "Every tool uses the same leading edge")
        precondition(abs(trailing - (width - Theme.Spacing.xxl)) < 1, "Every tool uses the same trailing edge")
        if [.json, .urlCodec, .base64, .hash].contains(tool) {
            precondition(frames.count == 2 && abs(frames[0].width - frames[1].width) < 1, "Stacked editors align")
        }
    }

    static func checkFields(_ root: NSView, tool: UtilityTool) {
        let inputs = fields(in: root).filter(\.isEditable)
        precondition(inputs.count == (tool == .timestamp ? 2 : 1), "Native input fields mount")
        for input in inputs {
            let frame = input.convert(input.bounds, to: root)
            precondition(root.bounds.contains(frame), "Native fields stay within the minimum window")
            let alignment = input.alignmentRect(forFrame: input.frame)
            let textFrame = input.superview?.convert(alignment, to: root) ?? frame
            precondition(abs(textFrame.minX - Theme.Spacing.xxl - Theme.Spacing.xl) < 1,
                         "Input text aligns with card titles: \(tool), field \(frame), text \(textFrame)")
        }
    }

    static func fields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { fields(in: $0) }
    }

    static func snapshot(_ root: NSView, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["TINYCAST_TOOL_PREVIEW_DIRECTORY"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        guard let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
            preconditionFailure("Cannot capture native tool view")
        }
        root.cacheDisplay(in: root.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            preconditionFailure("Cannot encode native tool view")
        }
        try data.write(to: url.appendingPathComponent(name + ".png"))
    }

    static func populate(_ coordinator: UtilityCoordinator, tool: UtilityTool) async throws {
        if tool == .timestamp {
            coordinator.timeZoneID = "UTC"
            coordinator.timestampInput = "1791849600"
            coordinator.dateInput = "2026-10-13 00:00:00"
            coordinator.convertTimestamp(fromDate: false)
            precondition(coordinator.timestampResult?.seconds == "1791849600")
            return
        }
        if tool == .currency {
            coordinator.rates.rates = CurrencyRates(base: "USD", rates: [
                "CNY": 7, "EUR": 0.9, "GBP": 0.77, "JPY": 149, "HKD": 7.8,
                "CAD": 1.4, "AUD": 1.5, "SGD": 1.3, "CHF": 0.84
            ], fetchedAt: Date(timeIntervalSince1970: 1791756000))
            coordinator.currencyInput = "100 CNY"
            precondition(coordinator.currencyValue(for: "USD") != nil)
            return
        }
        if tool == .json {
            coordinator.jsonInput = #"{"app":"Tinycast","native":true,"version":"0.11.24","tools":["JSON","Base64","Diff"]}"#
            coordinator.runJSON(.format)
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while coordinator.jsonBusy, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
            precondition(!coordinator.jsonBusy && !coordinator.jsonOutput.isEmpty)
            return
        }
        let session = coordinator.developerSession(for: tool)
        switch tool {
        case .urlCodec:
            session.input = "你好 Tinycast / tools?name=JSON"
            coordinator.runEncoding(tool, decoding: false)
        case .base64:
            session.input = "你好 👩🏽‍💻"
            coordinator.runEncoding(tool, decoding: false)
        case .uuid:
            session.uuidCount = 3
            coordinator.generateUUIDs()
        case .hash:
            session.input = "Hello, Tinycast!"
            session.hashAlgorithm = .sha512
            coordinator.computeHash()
        case .jwt:
            let header = try Base64Codec.encode(#"{"alg":"HS256","typ":"JWT"}"#, alphabet: .urlSafe)
            let payload = try Base64Codec.encode(
                #"{"name":"Tinycast","iat":1791849600,"nbf":1791849600,"exp":1893456000}"#, alphabet: .urlSafe)
            session.input = header + "." + payload + ".cHJldmlldw"
            coordinator.inspectJWT()
        case .textDiff:
            session.input = "const mode = 'light';\nconst tools = 6;\nopenWindow(mode);"
            session.comparisonInput = "const mode = 'system';\nconst tools = 7;\nopenWindow(mode);"
            coordinator.compareText()
        default: break
        }
        try await settled(session)
        if tool == .jwt { precondition(session.jwt?.claims.count == 3) }
    }

    static func diffRendering(_ coordinator: UtilityCoordinator, root: NSView) async throws {
        let session = coordinator.developerSession(for: .textDiff)
        session.input = "old\n"
        session.comparisonInput = "new\n"
        coordinator.compareText()
        try await settled(session)
        precondition(!session.isBusy && session.error.isEmpty)
        try await Task.sleep(for: .milliseconds(30))
        root.layoutSubtreeIfNeeded()
        guard let editor = editors(in: root).first(where: { !$0.isEditable }), let storage = editor.textStorage else {
            preconditionFailure("Missing read-only diff editor")
        }
        precondition(editor.string == "- old\n+ new")
        let removed = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let added = storage.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor
        precondition(removed == NSColor(Theme.Colors.utilityDiffRemoved))
        precondition(added == NSColor(Theme.Colors.utilityDiffAdded))
    }

    static func lifecycle(_ coordinator: UtilityCoordinator) async throws {
        coordinator.show(.urlCodec)
        coordinator.show(.base64)
        let oldSession = coordinator.developerSession(for: .urlCodec)
        oldSession.input = "old"
        coordinator.disappear(.urlCodec)
        precondition(coordinator.developerSession(for: .urlCodec) === oldSession)
        coordinator.runEncoding(.urlCodec, decoding: false)
        coordinator.close(.urlCodec)
        let base64Title = NSLocalizedString(UtilityTool.base64.title, comment: "Utility title")
        precondition(NSApp.windows.contains { $0.title == base64Title })
        coordinator.show(.urlCodec)
        let newSession = coordinator.developerSession(for: .urlCodec)
        precondition(newSession !== oldSession && newSession.input.isEmpty)
        newSession.input = "new text"
        coordinator.runEncoding(.urlCodec, decoding: false)
        try await settled(newSession)
        try await Task.sleep(for: .milliseconds(20))
        precondition(oldSession.output.isEmpty && !oldSession.isBusy)
        precondition(newSession.output == "new%20text")
        coordinator.close()
    }

    static func settled(_ session: DeveloperToolSession) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.isBusy, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
        precondition(!session.isBusy)
    }

    static func editors(in view: NSView) -> [NSTextView] {
        (view as? NSTextView).map { $0.isFieldEditor ? [] : [$0] } ?? view.subviews.flatMap { editors(in: $0) }
    }

    static func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}

@MainActor
final class AppCore {
    enum Tone { case danger }
    struct Palette {
        func hidePalette(restoreFocus: Bool) {}
    }
    let activationPolicy = ActivationPolicy()
    let paletteCoordinator = Palette()
    func showMessage(_ message: String, tone: Tone = .danger) {}
}

@MainActor
@Observable
final class CurrencyRateStore {
    var rates: CurrencyRates?
    var isRefreshing = false
    func refresh() async -> Bool { false }
}

@MainActor
enum Paster {
    static func copyPlainText(_ text: String) {}
}
