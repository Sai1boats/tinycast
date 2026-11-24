import SwiftUI

/// The phase hue is a mark colour — the dot, the rail, the badge — never a surface.
extension PomodoroPhase {
    var tint: Color {
        switch self {
        case .focus: Theme.Colors.brand
        case .shortBreak: Theme.Colors.success
        case .longBreak: Theme.Colors.primaryAction
        }
    }

    var label: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short Break")
        case .longBreak: String(localized: "Long Break")
        }
    }
}
