import AppKit
import SwiftUI

@MainActor
@Observable
final class PomodoroCoordinator {
    private let store: PomodoroStore
    private let settings: AppSettings
    private let appIndex: AppIndex
    private unowned let core: AppCore
    @ObservationIgnored private lazy var widget = PomodoroWidgetController(
        coordinator: self, core: core, settings: settings)

    private(set) var isExpanded = false
    private(set) var isWidgetVisible = false

    init(store: PomodoroStore, settings: AppSettings, appIndex: AppIndex, core: AppCore) {
        self.store = store
        self.settings = settings
        self.appIndex = appIndex
        self.core = core
        store.onPhaseCompleted = { [weak self] phase in self?.announce(phase) }
    }

    var state: PomodoroState { store.state }
    var stats: PomodoroStats { store.stats }
    var configuration: PomodoroConfiguration { store.configuration }
    var activeTaskID: UUID? { store.state.activeTaskID }

    var onFocusCompleted: ((UUID?, Int) -> Void)? {
        get { store.onFocusCompleted }
        set { store.onFocusCompleted = newValue }
    }

    var remainingText: String {
        PomodoroTimeText.minutesSeconds(PomodoroEngine.remaining(of: state, now: .now))
    }

    var elapsedText: String {
        PomodoroTimeText.minutesSeconds(
            configuration.duration(of: state.phase)
                - PomodoroEngine.remaining(of: state, now: .now))
    }

    /// Elapsed fraction of the current phase; the rail fills as time is spent.
    var progress: Double {
        PomodoroEngine.progress(of: state, now: .now, configuration: configuration)
    }

    /// Running pauses; a phase that never elapsed anything is a fresh start, not a resume.
    var primaryActionLabel: String {
        if state.isRunning { return String(localized: "Pause") }
        return progress > 0 ? String(localized: "Resume") : String(localized: "Start")
    }

    var primaryActionSymbol: String { state.isRunning ? "pause.fill" : "play.fill" }

    var titleText: String {
        let total = configuration.longBreakEvery
        // A skipped focus leaves cycleIndex at the break before it, which still owns an ordinal.
        let ordinal = state.phase == .focus
            ? min(state.cycleIndex + 1, total)
            : min(max(state.cycleIndex, 1), total)
        switch state.phase {
        case .focus: return String(localized: "Focus · \(ordinal) / \(total)")
        case .shortBreak: return String(localized: "Short Break · \(ordinal) / \(total)")
        case .longBreak: return String(localized: "Long Break · \(ordinal) / \(total)")
        }
    }

    func applyEnabled() {
        appIndex.setCommandsVisible([.showPomodoro, .startPomodoro], settings.pomodoroEnabled)
        guard settings.pomodoroEnabled else {
            isExpanded = false
            isWidgetVisible = false
            store.stop()
            widget.hide()
            return
        }
        store.updateConfiguration(settings.pomodoroConfiguration)
        store.start()
    }

    /// The command is a toggle: a second press puts the widget away.
    func toggleWidget() {
        if widget.isVisible {
            hideWidget()
        } else {
            showWidget()
        }
    }

    func showWidget() {
        guard settings.pomodoroEnabled else { return }
        widget.show(expanded: isExpanded)
        isWidgetVisible = true
    }

    func hideWidget() {
        collapseWidget()
        widget.hide()
        isWidgetVisible = false
    }

    func expandWidget() {
        guard settings.pomodoroEnabled else { return }
        isExpanded = true
        if widget.isVisible {
            widget.resizeToCurrentFace()
        } else {
            widget.show(expanded: true)
            isWidgetVisible = true
        }
    }

    func collapseWidget() {
        guard isExpanded else { return }
        isExpanded = false
        if widget.isVisible {
            widget.resizeToCurrentFace()
        }
    }

    /// Starts or resumes a session from the launcher and keeps the widget in view.
    func startPomodoro() {
        guard settings.pomodoroEnabled else { return }
        if !store.state.isRunning {
            store.toggleRunning()
        }
        showWidget()
    }

    func toggleRunning() {
        store.toggleRunning()
    }

    func skip() {
        store.skip()
    }

    func reset() {
        store.reset()
    }

    func setTaskName(_ taskName: String) {
        store.setTaskName(taskName)
    }

    func bindTask(id: UUID?, title: String) {
        store.bindTask(id: id, title: title)
    }

    func unbindTask() {
        store.unbindTask()
    }

    func focusTask(id: UUID?, title: String) {
        guard settings.pomodoroEnabled else { return }
        store.focusTask(id: id, title: title)
    }

    func applySettings() {
        store.updateConfiguration(settings.pomodoroConfiguration)
    }

    // MARK: - Private

    private func announce(_ phase: PomodoroPhase) {
        switch phase {
        case .focus:
            core.showMessage(String(localized: "Focus session complete."), tone: .success)
        case .shortBreak, .longBreak:
            core.showMessage(String(localized: "Break's over."), tone: .neutral)
        }
    }
}
