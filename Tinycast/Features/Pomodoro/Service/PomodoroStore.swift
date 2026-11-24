import Foundation
import Observation

/// Owns the live pomodoro session, the day's stats and their JSON file.
@MainActor
@Observable
final class PomodoroStore {
    private(set) var state: PomodoroState
    private(set) var stats: PomodoroStats
    private(set) var configuration: PomodoroConfiguration

    /// Reports a phase that ended by its deadline; skips stay silent.
    @ObservationIgnored var onPhaseCompleted: ((PomodoroPhase) -> Void)?
    /// Reports a focus phase completion with the bound task ID (if any) and focus minutes.
    @ObservationIgnored var onFocusCompleted: ((UUID?, Int) -> Void)?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var isEnabled: Bool
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var lastTickAt: Date?
    @ObservationIgnored private var focusAccumulator = PomodoroStats.FocusAccumulator()
    @ObservationIgnored private var unpersistedFocusSeconds = 0
    @ObservationIgnored private var taskNameWrite: Task<Void, Never>?
    @ObservationIgnored private var dayChangeToken: NotificationCenter.ObservationToken?
    @ObservationIgnored private var timeZoneToken: NotificationCenter.ObservationToken?

    /// A suspended Mac must not credit hours of focus time.
    private static let maxTickSeconds: TimeInterval = 2
    /// A quit mid-session must not lose more than half a minute of focus time.
    private static let focusPersistThreshold = 30

    init(
        fileURL: URL,
        configuration: PomodoroConfiguration,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now,
        isEnabled: Bool = true,
        clock: @escaping () -> Date = { .now }
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.clock = clock
        self.isEnabled = isEnabled
        let normalized = configuration.normalized
        self.configuration = normalized
        let today = PomodoroStats.dayKey(for: now, calendar: calendar)
        if let stored = Self.load(from: fileURL) {
            var stats = stored.stats.rolled(to: today)
            var restored = PomodoroEngine.restored(
                stored.state, configuration: normalized, now: now)
            if restored.isRunning, isEnabled {
                let settled = PomodoroEngine.settle(restored, now: now, configuration: normalized)
                if let completed = settled.completed {
                    stats = stats.recording(completed, at: now, calendar: calendar)
                }
                restored = settled.state
            }
            self.stats = stats
            self.state = restored
        } else {
            self.stats = PomodoroStats(day: today, completedFocusCount: 0, focusSeconds: 0)
            self.state = .idle(now: now, configuration: normalized)
        }
        observeCalendar()
        persistNow()
        if state.isRunning { startTicking() }
    }

    isolated deinit {
        tickTask?.cancel()
        taskNameWrite?.cancel()
        if let dayChangeToken { NotificationCenter.default.removeObserver(dayChangeToken) }
        if let timeZoneToken { NotificationCenter.default.removeObserver(timeZoneToken) }
    }

    // MARK: - Session actions

    func toggleRunning() {
        guard isEnabled else { return }
        let now = clock()
        accrueFocus(now: now)
        apply(PomodoroEngine.toggleRunning(state, now: now, configuration: configuration))
    }

    func skip() {
        guard isEnabled else { return }
        let now = clock()
        accrueFocus(now: now)
        apply(PomodoroEngine.skip(state, now: now, configuration: configuration))
    }

    func reset() {
        guard isEnabled else { return }
        let now = clock()
        accrueFocus(now: now)
        apply(PomodoroEngine.reset(state, now: now, configuration: configuration))
    }

    func setTaskName(_ taskName: String) {
        state = PomodoroEngine.setTaskName(state, taskName: taskName).state
        taskNameWrite?.cancel()
        taskNameWrite = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.taskNameWrite = nil
            self?.persist()
        }
    }

    func bindTask(id: UUID?, title: String) {
        state = PomodoroEngine.setTask(state, id: id, name: title).state
        persistNow()
    }

    func unbindTask() {
        bindTask(id: nil, title: "")
    }

    func focusTask(id: UUID?, title: String) {
        guard isEnabled else { return }
        let now = clock()
        accrueFocus(now: now)
        apply(PomodoroEngine.focusTask(
            state, id: id, name: title, now: now, configuration: configuration))
    }

    func updateConfiguration(_ configuration: PomodoroConfiguration) {
        let normalized = configuration.normalized
        let previous = self.configuration
        guard normalized != previous else {
            if state.isRunning { startTicking() }
            return
        }
        let now = clock()
        accrueFocus(now: now)
        let completed = isEnabled ? settleIfDue(now: now) : nil
        self.configuration = normalized
        state = PomodoroEngine.reanchor(state, from: previous, to: normalized, now: now)
        if state.isRunning { startTicking() }
        if let completed {
            announceCompletion(completed)
        } else {
            persistNow()
        }
    }

    func start() {
        isEnabled = true
        if let completed = settleIfDue(now: clock()) { announceCompletion(completed) }
        if state.isRunning { startTicking() }
    }

    func stop() {
        accrueFocus(now: clock())
        isEnabled = false
        stopTicking()
        if taskNameWrite != nil || unpersistedFocusSeconds > 0 { persistNow() }
    }

    // MARK: - Ticking

    private func startTicking() {
        guard isEnabled, tickTask == nil else { return }
        lastTickAt = clock()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        lastTickAt = nil
    }

    private func accrueFocus(now: Date) {
        guard let previous = lastTickAt else { return }
        lastTickAt = now
        let today = dayKey(now)
        if stats.day != today {
            stats = stats.rolled(to: today)
            focusAccumulator = PomodoroStats.FocusAccumulator()
        }
        guard state.phase == .focus, state.isRunning, let deadline = state.endsAt else { return }
        let start = max(previous, calendar.startOfDay(for: now))
        let end = min(now, deadline)
        let capped = min(Self.maxTickSeconds, max(0, end.timeIntervalSince(start)))
        let wholeSeconds = focusAccumulator.record(capped)
        stats = stats.addingFocusSeconds(wholeSeconds, on: today)
        unpersistedFocusSeconds += wholeSeconds
    }

    private func tick() {
        let now = clock()
        accrueFocus(now: now)
        let completed = settleIfDue(now: now)
        if state.isRunning {
            state.remaining = PomodoroEngine.remaining(of: state, now: now)
        }
        if let completed {
            announceCompletion(completed)
        } else if unpersistedFocusSeconds >= Self.focusPersistThreshold {
            persistNow()
        }
    }

    private func apply(_ transition: PomodoroEngine.Transition) {
        state = transition.state
        if state.isRunning {
            startTicking()
        } else {
            stopTicking()
        }
        if let completed = transition.completed {
            stats = stats.recording(completed, at: clock(), calendar: calendar)
            announceCompletion(completed)
        } else {
            persistNow()
        }
    }

    /// Completes a phase whose deadline passed while the loop was not running, such as after a disable.
    private func settleIfDue(now: Date) -> PomodoroPhase? {
        let settled = PomodoroEngine.settle(state, now: now, configuration: configuration)
        guard let completed = settled.completed else { return nil }
        state = settled.state
        stats = stats.recording(completed, at: now, calendar: calendar)
        return completed
    }

    private func announceCompletion(_ phase: PomodoroPhase) {
        persistNow()
        if phase == .focus {
            onFocusCompleted?(state.activeTaskID, configuration.focusMinutes)
        }
        onPhaseCompleted?(phase)
    }

    private func dayKey(_ date: Date) -> String {
        PomodoroStats.dayKey(for: date, calendar: calendar)
    }

    // MARK: - Calendar

    /// A day change must roll the bucket even while the timer is paused or the feature is off.
    private func observeCalendar() {
        dayChangeToken = NotificationCenter.default.addObserver(
            of: Calendar.self, for: .calendarDayChanged
        ) { [weak self] _ in
            await self?.rollStats()
        }
        timeZoneToken = NotificationCenter.default.addObserver(
            of: TimeZone.self, for: .systemTimeZoneDidChange
        ) { [weak self] _ in
            self?.rollStats()
        }
    }

    private func rollStats() {
        let today = dayKey(clock())
        guard stats.day != today else { return }
        stats = stats.rolled(to: today)
        focusAccumulator = PomodoroStats.FocusAccumulator()
        persistNow()
    }

    // MARK: - Persistence

    private struct FileState: Codable {
        var state: PomodoroState
        var stats: PomodoroStats
    }

    private func persistNow() {
        taskNameWrite?.cancel()
        taskNameWrite = nil
        persist()
    }

    private func persist() {
        unpersistedFocusSeconds = 0
        let payload = FileState(state: state, stats: stats)
        do {
            let data = try JSONEncoder().encode(payload)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // The file only restores a session on relaunch; the running timer is unaffected.
        }
    }

    private static func load(from fileURL: URL) -> FileState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(FileState.self, from: data)
    }
}
