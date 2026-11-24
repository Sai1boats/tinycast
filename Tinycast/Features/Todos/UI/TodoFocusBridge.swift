import Foundation
import Observation

/// Decoupled bridge exposing Pomodoro state/actions to Local Todos without importing Pomodoro.
@MainActor
@Observable
final class TodoFocusBridge {
    enum PhaseKind: Equatable, Sendable {
        case focus, shortBreak, longBreak
    }

    struct Snapshot: Equatable, Sendable {
        var isEnabled: Bool
        var isRunning: Bool
        var isIdle: Bool
        var phaseKind: PhaseKind
        var phaseTitle: String
        var remainingText: String
        var progress: Double
        var activeTaskID: UUID?
        var activeTaskTitle: String
        var todayCount: Int
        var todayMinutes: Int
        var isWidgetVisible: Bool
    }

    @ObservationIgnored private let readSnapshot: () -> Snapshot
    @ObservationIgnored private let onToggleRunning: () -> Void
    @ObservationIgnored private let onSkip: () -> Void
    @ObservationIgnored private let onFocusTask: (UUID?, String) -> Void
    @ObservationIgnored private let onUnbindTask: () -> Void
    @ObservationIgnored private let onToggleWidget: () -> Void

    init(
        readSnapshot: @escaping () -> Snapshot,
        onToggleRunning: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onFocusTask: @escaping (UUID?, String) -> Void,
        onUnbindTask: @escaping () -> Void,
        onToggleWidget: @escaping () -> Void
    ) {
        self.readSnapshot = readSnapshot
        self.onToggleRunning = onToggleRunning
        self.onSkip = onSkip
        self.onFocusTask = onFocusTask
        self.onUnbindTask = onUnbindTask
        self.onToggleWidget = onToggleWidget
    }

    var snapshot: Snapshot { readSnapshot() }

    func toggleRunning() { onToggleRunning() }
    func skip() { onSkip() }
    func focusTask(id: UUID?, title: String) { onFocusTask(id, title) }
    func unbindTask() { onUnbindTask() }
    func toggleWidget() { onToggleWidget() }
}
