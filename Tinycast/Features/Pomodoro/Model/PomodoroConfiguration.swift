import Foundation

struct PomodoroConfiguration: Codable, Sendable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    /// Focus sessions between long breaks.
    var longBreakEvery: Int

    static let standard = PomodoroConfiguration(
        focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 4)

    static let focusRange = 1...180
    static let breakRange = 1...60
    static let cycleRange = 1...12

    var normalized: PomodoroConfiguration {
        PomodoroConfiguration(
            focusMinutes: clamp(focusMinutes, to: Self.focusRange),
            shortBreakMinutes: clamp(shortBreakMinutes, to: Self.breakRange),
            longBreakMinutes: clamp(longBreakMinutes, to: Self.breakRange),
            longBreakEvery: clamp(longBreakEvery, to: Self.cycleRange))
    }

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: TimeInterval(focusMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    private func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }
}
