import Foundation

enum LauncherTabDestination: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case none
    case clipboard
    case ai
    case fileSearch
    case emoji
    case calculatorHistory
    case quicklinks
    case snippets
    case customCommands
    case dictionary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: String(localized: "Default cycle")
        case .none: String(localized: "None")
        case .clipboard: String(localized: "Clipboard History")
        case .ai: String(localized: "Quick AI")
        case .fileSearch: String(localized: "Search Files")
        case .emoji: String(localized: "Emoji & Symbols")
        case .calculatorHistory: String(localized: "Calculator History")
        case .quicklinks: String(localized: "Search Quicklinks")
        case .snippets: String(localized: "Search Snippets")
        case .customCommands: String(localized: "Search Custom Commands")
        case .dictionary: String(localized: "Dictionary")
        }
    }
}
