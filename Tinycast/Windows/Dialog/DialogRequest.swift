import Foundation
import Observation

/// One button; role decides its colour, severity living separately in `DialogTone`.
struct DialogAction {
    enum Role {
        case standard
        case destructive
        case cancel
    }

    let title: String
    var role: Role = .standard
    var symbol: String?
}

/// How serious a dialog is; it tints the glyph but never picks one. See docs/ui.md.
enum DialogTone: Sendable {
    case neutral
    case success
    case danger
}

struct DialogRequest {
    let title: String
    var message: String?
    /// Nil where the title already names the subject and a glyph would repeat it.
    let symbol: String?
    var tone: DialogTone = .neutral
    var actions: [DialogAction]
    /// The button ↵ fires, normally the primary action.
    var defaultIndex: Int
    /// Resolved when the dialog goes without a choice: Esc, or losing key status.
    var cancelIndex: Int
    /// The caller reads the result back out of the state object it passed in.
    var accessory: DialogAccessory?

    @MainActor var canConfirm: Bool {
        if case .name(let state) = accessory { return !state.name.isEmpty }
        return true
    }
}

/// A dialog carries at most one control, so the cases are exclusive by construction.
enum DialogAccessory {
    case name(DialogNameState)
    case volume(VolumeState)
    case snippetArguments(SnippetArgumentsState)
    case clipboardText(ClipboardEditState)

    /// Whether ←/→/↑/↓ belong to the control rather than to whatever has focus inside it.
    var claimsArrowKeys: Bool {
        if case .volume = self { return true }
        return false
    }

    /// Whether ↵ belongs to a multi-line field, which leaves ⌘↵ to confirm the dialog.
    var acceptsLineBreaks: Bool {
        if case .clipboardText = self { return true }
        return false
    }
}

@MainActor @Observable
final class DialogNameState {
    var text: String

    init(text: String) { self.text = text }
    var name: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
