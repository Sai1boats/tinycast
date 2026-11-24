import Foundation

enum PomodoroPhase: String, Codable, Sendable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .focus }
}
