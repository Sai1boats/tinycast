import Foundation

enum ShellCommandDestination: String, CaseIterable, Identifiable, Sendable {
    case tinycast
    case terminal
    case iterm
    case cmux

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tinycast: "Tinycast (Internal)"
        case .terminal: "Terminal"
        case .iterm: "iTerm"
        case .cmux: "cmux"
        }
    }

    var bundleID: String? {
        switch self {
        case .tinycast: nil
        case .terminal: "com.apple.Terminal"
        case .iterm: "com.googlecode.iterm2"
        case .cmux: "com.cmuxterm.app"
        }
    }
}
