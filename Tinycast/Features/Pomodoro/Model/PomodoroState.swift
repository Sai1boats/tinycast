import Foundation

struct PomodoroState: Codable, Sendable, Equatable {
    var phase: PomodoroPhase
    var isRunning: Bool
    /// Set only while running; `remaining` is authoritative otherwise.
    var endsAt: Date?
    var remaining: TimeInterval
    /// Focus sessions run since the last long break; resets when one ends.
    var cycleIndex: Int
    var taskName: String
    /// Optional bound LocalTodo ID; nil runs the timer in task-free Free Focus mode.
    var activeTaskID: UUID?

    static func idle(now: Date, configuration: PomodoroConfiguration) -> PomodoroState {
        PomodoroState(
            phase: .focus,
            isRunning: false,
            endsAt: nil,
            remaining: configuration.duration(of: .focus),
            cycleIndex: 0,
            taskName: "",
            activeTaskID: nil)
    }
}
