import Foundation

/// Pure pomodoro transitions; every decision takes the current instant as a parameter.
enum PomodoroEngine {
    struct Transition: Sendable, Equatable {
        var state: PomodoroState
        /// Set when a phase ended by its deadline; a skip reports nil.
        var completed: PomodoroPhase?
    }

    static func start(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        guard !state.isRunning else { return Transition(state: state, completed: nil) }
        // A paused phase at zero already passed its deadline; resuming it must settle, not run empty.
        guard state.remaining > 0 else {
            return advance(state, now: now, configuration: configuration)
        }
        return Transition(state: running(state, from: state.remaining, now: now), completed: nil)
    }

    static func pause(_ state: PomodoroState, now: Date) -> Transition {
        guard state.isRunning else { return Transition(state: state, completed: nil) }
        var paused = state
        paused.remaining = remaining(of: state, now: now)
        paused.isRunning = false
        paused.endsAt = nil
        return Transition(state: paused, completed: nil)
    }

    static func resume(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        start(state, now: now, configuration: configuration)
    }

    static func toggleRunning(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        state.isRunning
            ? pause(state, now: now)
            : start(state, now: now, configuration: configuration)
    }

    /// Jumps to the next phase without reporting a completion, so the cycle does not move.
    static func skip(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        let next = followingPhase(
            of: state.phase, cycleIndex: state.cycleIndex, configuration: configuration)
        var advanced = state
        advanced.phase = next.phase
        advanced.cycleIndex = next.cycleIndex
        advanced.remaining = configuration.duration(of: next.phase)
        advanced.endsAt = nil
        if state.isRunning {
            advanced = running(advanced, from: advanced.remaining, now: now)
        }
        return Transition(state: advanced, completed: nil)
    }

    /// Back to an idle focus, keeping only the bound task.
    static func reset(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        var idle = PomodoroState.idle(now: now, configuration: configuration)
        idle.taskName = state.taskName
        idle.activeTaskID = state.activeTaskID
        return Transition(state: idle, completed: nil)
    }

    static func setTaskName(_ state: PomodoroState, taskName: String) -> Transition {
        var updated = state
        updated.taskName = taskName
        return Transition(state: updated, completed: nil)
    }

    static func setTask(_ state: PomodoroState, id: UUID?, name: String) -> Transition {
        var updated = state
        updated.activeTaskID = id
        updated.taskName = name
        return Transition(state: updated, completed: nil)
    }

    /// Binds a task (or nil for Free Focus) and ensures a focus session is running.
    static func focusTask(
        _ state: PomodoroState, id: UUID?, name: String, now: Date,
        configuration: PomodoroConfiguration
    ) -> Transition {
        var updated = state
        updated.activeTaskID = id
        updated.taskName = name
        if updated.phase != .focus {
            updated.phase = .focus
            updated.isRunning = false
            updated.endsAt = nil
            updated.remaining = configuration.duration(of: .focus)
        }
        return start(updated, now: now, configuration: configuration)
    }

    /// Advances exactly one phase once its deadline has passed; an overslept session anchors at now.
    static func settle(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        guard state.isRunning, let endsAt = state.endsAt, now >= endsAt else {
            return Transition(state: state, completed: nil)
        }
        return advance(state, now: now, configuration: configuration)
    }

    /// Keeps the elapsed part of the phase when a duration setting changes, running or paused.
    static func reanchor(
        _ state: PomodoroState, from previous: PomodoroConfiguration,
        to configuration: PomodoroConfiguration, now: Date
    ) -> PomodoroState {
        let oldDuration = previous.duration(of: state.phase)
        let elapsed = Swift.min(oldDuration, Swift.max(0, oldDuration - remaining(of: state, now: now)))
        var reanchored = state
        reanchored.remaining = Swift.max(0, configuration.duration(of: state.phase) - elapsed)
        if state.isRunning {
            reanchored.endsAt = now.addingTimeInterval(reanchored.remaining)
        }
        return reanchored
    }

    /// Repairs a decoded session: a run without a deadline is paused, and a remainder never outlives its phase.
    static func restored(
        _ state: PomodoroState, configuration: PomodoroConfiguration, now: Date
    ) -> PomodoroState {
        var restored = state
        restored.cycleIndex = min(max(0, state.cycleIndex), PomodoroConfiguration.cycleRange.upperBound)
        let duration = configuration.duration(of: restored.phase)
        guard restored.isRunning, let endsAt = restored.endsAt else {
            restored.isRunning = false
            restored.endsAt = nil
            restored.remaining = Swift.min(duration, Swift.max(0, restored.remaining))
            return restored
        }
        let left = endsAt.timeIntervalSince(now)
        if left > duration {
            restored.remaining = duration
            restored.endsAt = now.addingTimeInterval(duration)
        } else {
            restored.remaining = Swift.max(0, left)
        }
        return restored
    }

    static func remaining(of state: PomodoroState, now: Date) -> TimeInterval {
        guard state.isRunning, let endsAt = state.endsAt else { return state.remaining }
        return Swift.max(0, endsAt.timeIntervalSince(now))
    }

    /// Elapsed fraction of the current phase, 0…1.
    static func progress(
        of state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Double {
        let duration = configuration.duration(of: state.phase)
        guard duration > 0 else { return 0 }
        let done = duration - remaining(of: state, now: now)
        return Swift.min(1, Swift.max(0, done / duration))
    }

    // MARK: - Private

    /// Advances exactly one phase and anchors the next one at `now`.
    private static func advance(
        _ state: PomodoroState, now: Date, configuration: PomodoroConfiguration
    ) -> Transition {
        let completed = state.phase
        var advanced = state
        if completed == .focus {
            advanced.cycleIndex += 1
        }
        let next = followingPhase(
            of: completed, cycleIndex: advanced.cycleIndex, configuration: configuration)
        advanced.phase = next.phase
        advanced.cycleIndex = next.cycleIndex
        advanced.remaining = configuration.duration(of: next.phase)
        advanced = running(advanced, from: advanced.remaining, now: now)
        return Transition(state: advanced, completed: completed)
    }

    private static func running(_ state: PomodoroState, from remaining: TimeInterval, now: Date)
        -> PomodoroState
    {
        var running = state
        running.isRunning = true
        running.remaining = remaining
        running.endsAt = now.addingTimeInterval(remaining)
        return running
    }

    /// `cycleIndex` is the focus count after the move; a skip never adds one.
    private static func followingPhase(
        of phase: PomodoroPhase, cycleIndex: Int, configuration: PomodoroConfiguration
    ) -> (phase: PomodoroPhase, cycleIndex: Int) {
        switch phase {
        case .focus:
            return cycleIndex >= configuration.longBreakEvery
                ? (.longBreak, cycleIndex) : (.shortBreak, cycleIndex)
        case .shortBreak:
            return (.focus, cycleIndex)
        case .longBreak:
            return (.focus, 0)
        }
    }
}
