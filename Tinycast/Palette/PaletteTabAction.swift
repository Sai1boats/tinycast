import Foundation

enum PaletteTabAction: Equatable {
    /// The typed text rides along, because both ends narrow their own list by the same query.
    case carryQuery(PaletteMode)
    /// A fresh screen: chat's field holds a half-written message, which is nobody else's search.
    case freshScreen(PaletteMode)
    /// The typed text is the question, so chat opens on the answer rather than an empty composer.
    case ask

    static func resolve(
        mode: PaletteMode, destination: LauncherTabDestination,
        enabled: Set<LauncherTabDestination>
    ) -> Self {
        if mode == .launcher, destination != .automatic {
            guard enabled.contains(destination) else { return .carryQuery(.launcher) }
            switch destination {
            case .automatic, .none: return .carryQuery(.launcher)
            case .ai: return .ask
            case .clipboard: return .freshScreen(.clipboard)
            case .fileSearch: return .carryQuery(.fileSearch)
            case .emoji: return .carryQuery(.emoji)
            case .calculatorHistory: return .carryQuery(.calculatorHistory)
            case .quicklinks: return .carryQuery(.quicklinks)
            case .snippets: return .carryQuery(.snippets)
            case .customCommands: return .carryQuery(.customCommands)
            case .dictionary: return .carryQuery(.dictionary)
            }
        }
        if destination != .automatic { return .carryQuery(.launcher) }
        switch mode {
        // A stop that is off leaves the ring, so Tab skips it rather than opening nothing.
        case .launcher:
            if enabled.contains(.ai) { return .ask }
            return enabled.contains(.clipboard) ? .carryQuery(.clipboard) : .carryQuery(.launcher)
        case .ai:
            return enabled.contains(.clipboard) ? .freshScreen(.clipboard) : .carryQuery(.launcher)
        case .clipboard: return .carryQuery(.launcher)
        default: return .carryQuery(.launcher)
        }
    }
}
