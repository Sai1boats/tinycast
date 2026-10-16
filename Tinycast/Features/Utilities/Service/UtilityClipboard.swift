import AppKit

/// What the utility windows may learn about the clipboard before the reader asks for it.
@MainActor
enum UtilityClipboard {
    static var changeCount: Int { NSPasteboard.general.changeCount }

    /// Nil for a copy a password manager or the OS marked secret, so no suggestion names one.
    static func text() -> String? {
        let pasteboard = NSPasteboard.general
        guard pasteboard.types?.contains(where: ClipboardManager.sensitiveTypes.contains) != true else { return nil }
        return pasteboard.string(forType: .string)
    }
}
