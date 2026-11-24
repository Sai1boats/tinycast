import SwiftUI

extension TodoPriority {
    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    var tint: Color {
        switch self {
        case .none: Theme.Colors.textTertiary
        case .low: Theme.Colors.brand
        case .medium: Theme.Colors.warning
        case .high: Theme.Colors.destructive
        }
    }
}

extension TodoFocusBridge.PhaseKind {
    var tint: Color {
        switch self {
        case .focus: Theme.Colors.brand
        case .shortBreak: Theme.Colors.success
        case .longBreak: Theme.Colors.primaryAction
        }
    }
}

extension TodoReminderPreset {
    var title: String {
        switch self {
        case .in30Minutes: String(localized: "In 30 min")
        case .tonight: String(localized: "Tonight 18:00")
        case .tomorrowMorning: String(localized: "Tomorrow 09:00")
        case .nextMonday: String(localized: "Next Monday")
        }
    }
}

extension Color {
    init(todoProjectHex hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
            self = Theme.Colors.brand
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
