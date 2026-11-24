import Foundation

@main
@MainActor
struct PomodoroTests {
    private static var failures = 0

    static func main() async throws {
        testInitialState()
        testStartAndRemaining()
        testPauseResume()
        testToggleRunning()
        testFocusCompletionAdvancesToShortBreak()
        testCycleReachesLongBreak()
        testLongBreakReturnsToFreshCycle()
        testSkipDoesNotCount()
        testSkipBreakReturnsToFocus()
        testResetKeepsTaskName()
        testSettleCompletesOnePhaseAfterSleep()
        testSettleIgnoresPausedState()
        testStartSettlesDepletedPhase()
        testPauseAtDeadlineSettlesOnResume()
        testProgress()
        testSetTaskName()
        testConfigurationNormalization()
        testConfigReanchor()
        testRestoredNormalization()
        testStatsDayRoll()
        testStatsAccumulation()
        testStatsCompletionDay()
        testFocusSecondsAccumulator()
        testTimeText()
        testTaskBindingAndFreeFocus()
        try await testStoreLifecycle()

        print(failures == 0 ? "Pomodoro tests passed" : "\(failures) tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    private static let configuration = PomodoroConfiguration(
        focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 2)
    private static let now = Date(timeIntervalSince1970: 1_770_000_000)

    private static func idle() -> PomodoroState {
        PomodoroState.idle(now: now, configuration: configuration)
    }

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private static func testStoreLifecycle() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(now)
        let url = directory.appendingPathComponent("session.json")
        let store = PomodoroStore(fileURL: url, configuration: configuration, now: now,
                                  clock: { clock.now })
        for _ in 0..<8 {
            store.toggleRunning()
            clock.now = clock.now.addingTimeInterval(0.25)
            store.toggleRunning()
        }
        check("pauses credit time between ticks", store.stats.focusSeconds == 2)
        store.toggleRunning()
        store.stop()
        clock.now = now.addingTimeInterval(2000)
        var changed = configuration
        changed.longBreakEvery = 3
        store.updateConfiguration(changed)
        try await Task.sleep(for: .milliseconds(650))
        check("disabled settings cannot complete a phase", store.stats.completedFocusCount == 0)
        store.start()
        check("enabling settles one overdue phase", store.stats.completedFocusCount == 1)
        store.stop()

        let overdueURL = directory.appendingPathComponent("overdue.json")
        let overdue = PomodoroStore(fileURL: overdueURL, configuration: configuration, now: now,
                                    clock: { clock.now })
        clock.now = now
        overdue.toggleRunning()
        overdue.stop()
        clock.now = now.addingTimeInterval(2000)
        let restored = PomodoroStore(fileURL: overdueURL, configuration: configuration,
                                     now: clock.now, clock: { clock.now })
        check("restore completes an overdue focus once", restored.stats.completedFocusCount == 1)
        restored.setTaskName("Saved on quit")
        restored.stop()
        clock.now = clock.now.addingTimeInterval(10)
        let reloaded = PomodoroStore(fileURL: overdueURL, configuration: configuration,
                                     now: clock.now, clock: { clock.now })
        check("restored phase deadline survives another launch",
              reloaded.state.endsAt == restored.state.endsAt)
        check("stopping flushes a pending task-name edit", reloaded.state.taskName == "Saved on quit")
        reloaded.stop()

        let cappedURL = directory.appendingPathComponent("capped.json")
        clock.now = now
        let capped = PomodoroStore(fileURL: cappedURL, configuration: configuration, now: now,
                                   clock: { clock.now })
        capped.toggleRunning()
        clock.now = now.addingTimeInterval(1499.5)
        capped.updateConfiguration(changed)
        let seconds = capped.stats.focusSeconds
        clock.now = now.addingTimeInterval(1501)
        capped.toggleRunning()
        check("time after the deadline is not focus time", capped.stats.focusSeconds == seconds)
        capped.stop()

        let callbackURL = directory.appendingPathComponent("callback.json")
        clock.now = now
        let callbackStore = PomodoroStore(
            fileURL: callbackURL, configuration: configuration, now: now, clock: { clock.now })
        var recorded: [(UUID?, Int)] = []
        callbackStore.onFocusCompleted = { id, minutes in recorded.append((id, minutes)) }
        let boundID = UUID()
        callbackStore.focusTask(id: boundID, title: "Write tests")
        callbackStore.stop()
        clock.now = now.addingTimeInterval(1600)
        callbackStore.start()
        check("bound focus completion notifies callback",
              recorded.count == 1 && recorded[0].0 == boundID && recorded[0].1 == 25)
        callbackStore.unbindTask()
        check("unbindTask clears activeTaskID while running free focus",
              callbackStore.state.activeTaskID == nil && callbackStore.state.taskName.isEmpty)
        callbackStore.stop()
    }

    // MARK: - Engine

    private static func testInitialState() {
        let state = idle()
        check("initial phase is focus", state.phase == .focus)
        check("initial is idle", !state.isRunning)
        check("initial remaining is the focus duration", state.remaining == 25 * 60)
        check("initial cycle is empty", state.cycleIndex == 0)
    }

    private static func testStartAndRemaining() {
        let transition = PomodoroEngine.start(idle(), now: now, configuration: configuration)
        check("start reports no completion", transition.completed == nil)
        check("start runs the session", transition.state.isRunning)
        check(
            "start ends one focus from now",
            transition.state.endsAt == now.addingTimeInterval(25 * 60))
        let later = now.addingTimeInterval(100)
        check(
            "remaining counts down",
            PomodoroEngine.remaining(of: transition.state, now: later) == 25 * 60 - 100)
        check("start is idempotent", PomodoroEngine.start(transition.state, now: later,
            configuration: configuration).state == transition.state)
    }

    private static func testPauseResume() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let later = now.addingTimeInterval(90)
        let paused = PomodoroEngine.pause(running, now: later)
        check("pause reports no completion", paused.completed == nil)
        check("pause stops the session", !paused.state.isRunning)
        check("pause clears the deadline", paused.state.endsAt == nil)
        check("pause freezes remaining", paused.state.remaining == 25 * 60 - 90)
        let muchLater = now.addingTimeInterval(500)
        check(
            "a paused session does not drift",
            PomodoroEngine.remaining(of: paused.state, now: muchLater) == 25 * 60 - 90)
        let resumed = PomodoroEngine.resume(paused.state, now: muchLater, configuration: configuration)
        check("resume runs again", resumed.state.isRunning)
        check(
            "resume continues from the frozen remainder",
            resumed.state.endsAt == muchLater.addingTimeInterval(25 * 60 - 90))
    }

    private static func testToggleRunning() {
        let running = PomodoroEngine.toggleRunning(idle(), now: now, configuration: configuration)
        check("toggle starts an idle session", running.state.isRunning)
        let paused = PomodoroEngine.toggleRunning(
            running.state, now: now, configuration: configuration)
        check("toggle pauses a running session", !paused.state.isRunning)
    }

    private static func testFocusCompletionAdvancesToShortBreak() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let end = now.addingTimeInterval(25 * 60)
        let settled = PomodoroEngine.settle(running, now: end, configuration: configuration)
        check("a finished focus reports completion", settled.completed == .focus)
        check("the next phase is a short break", settled.state.phase == .shortBreak)
        check("the break runs", settled.state.isRunning)
        check("the cycle counts the focus", settled.state.cycleIndex == 1)
        check(
            "the break ends one break after the deadline",
            settled.state.endsAt == end.addingTimeInterval(5 * 60))
    }

    private static func testCycleReachesLongBreak() {
        var state = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        var cursor = now
        cursor = state.endsAt ?? cursor
        state = PomodoroEngine.settle(state, now: cursor, configuration: configuration).state
        check("after one focus the break is short", state.phase == .shortBreak)
        cursor = state.endsAt ?? cursor
        state = PomodoroEngine.settle(state, now: cursor, configuration: configuration).state
        check("after the break the cycle returns to focus", state.phase == .focus)
        check("the cycle counted the first focus", state.cycleIndex == 1)
        cursor = state.endsAt ?? cursor
        let finished = PomodoroEngine.settle(state, now: cursor, configuration: configuration)
        check("the second focus completion reports", finished.completed == .focus)
        check("the cycle then takes a long break", finished.state.phase == .longBreak)
    }

    private static func testLongBreakReturnsToFreshCycle() {
        var state = idle()
        state.cycleIndex = 2
        state.phase = .longBreak
        state.remaining = 15 * 60
        let running = PomodoroEngine.start(state, now: now, configuration: configuration).state
        let settled = PomodoroEngine.settle(
            running, now: now.addingTimeInterval(15 * 60), configuration: configuration)
        check("a finished long break reports", settled.completed == .longBreak)
        check("the next phase is focus", settled.state.phase == .focus)
        check("the cycle resets", settled.state.cycleIndex == 0)
    }

    private static func testSkipDoesNotCount() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let skipped = PomodoroEngine.skip(running, now: now, configuration: configuration)
        check("a skip reports no completion", skipped.completed == nil)
        check("a skipped focus breaks next", skipped.state.phase == .shortBreak)
        check("a skip leaves the cycle alone", skipped.state.cycleIndex == 0)
        check("a skip keeps running", skipped.state.isRunning)
        check(
            "a skipped break is a full break",
            skipped.state.endsAt == now.addingTimeInterval(5 * 60))
    }

    private static func testSkipBreakReturnsToFocus() {
        var state = idle()
        state.phase = .shortBreak
        state.remaining = 5 * 60
        state.cycleIndex = 1
        let skipped = PomodoroEngine.skip(state, now: now, configuration: configuration)
        check("a skipped break focuses next", skipped.state.phase == .focus)
        check("a skipped break keeps the cycle", skipped.state.cycleIndex == 1)
        check("a skipped break stays idle", !skipped.state.isRunning)
    }

    private static func testResetKeepsTaskName() {
        var state = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        state = PomodoroEngine.setTaskName(state, taskName: "Write the spec").state
        let reset = PomodoroEngine.reset(state, now: now, configuration: configuration)
        check("reset reports no completion", reset.completed == nil)
        check("reset idles", !reset.state.isRunning)
        check("reset returns to focus", reset.state.phase == .focus)
        check("reset restores the full focus", reset.state.remaining == 25 * 60)
        check("reset keeps the task name", reset.state.taskName == "Write the spec")
        check("reset clears the cycle", reset.state.cycleIndex == 0)
    }

    private static func testSettleCompletesOnePhaseAfterSleep() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let wake = now.addingTimeInterval(3 * 3600)
        let settled = PomodoroEngine.settle(running, now: wake, configuration: configuration)
        check("a sleep gap completes one phase", settled.completed == .focus)
        check("the next phase runs", settled.state.isRunning)
        check(
            "the next phase starts at wake, not at the old deadline",
            settled.state.endsAt == wake.addingTimeInterval(5 * 60))
    }

    private static func testSettleIgnoresPausedState() {
        let paused = PomodoroEngine.pause(
            PomodoroEngine.start(idle(), now: now, configuration: configuration).state,
            now: now.addingTimeInterval(10))
        let settled = PomodoroEngine.settle(
            paused.state, now: now.addingTimeInterval(3600), configuration: configuration)
        check("a paused session never settles", settled.completed == nil)
        check("a paused session keeps its phase", settled.state == paused.state)
    }

    private static func testStartSettlesDepletedPhase() {
        var depleted = idle()
        depleted.remaining = 0
        let resumed = PomodoroEngine.start(depleted, now: now, configuration: configuration)
        check("a depleted focus reports its completion", resumed.completed == .focus)
        check("a depleted focus breaks next", resumed.state.phase == .shortBreak)
        check("the completion advances the cycle", resumed.state.cycleIndex == 1)
        check("the next phase runs", resumed.state.isRunning)
        check(
            "the next phase starts at the resume instant",
            resumed.state.endsAt == now.addingTimeInterval(5 * 60))

        var depletedBreak = idle()
        depletedBreak.phase = .shortBreak
        depletedBreak.remaining = -1
        depletedBreak.cycleIndex = 1
        let resumedBreak = PomodoroEngine.start(
            depletedBreak, now: now, configuration: configuration)
        check("a depleted break reports its completion", resumedBreak.completed == .shortBreak)
        check("a depleted break focuses next", resumedBreak.state.phase == .focus)
        check("a depleted break keeps the cycle", resumedBreak.state.cycleIndex == 1)
    }

    private static func testPauseAtDeadlineSettlesOnResume() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let deadline = now.addingTimeInterval(25 * 60)
        let paused = PomodoroEngine.pause(running, now: deadline)
        check("pausing at the deadline leaves nothing", paused.state.remaining == 0)
        check("pausing at the deadline reports nothing", paused.completed == nil)
        let resumed = PomodoroEngine.resume(
            paused.state, now: deadline, configuration: configuration)
        check("resuming at the deadline completes the focus", resumed.completed == .focus)
        check("resuming at the deadline starts the break", resumed.state.phase == .shortBreak)
        check(
            "the break is anchored at the resume instant",
            resumed.state.endsAt == deadline.addingTimeInterval(5 * 60))
    }

    private static func testProgress() {
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        check("progress starts empty", PomodoroEngine.progress(of: running, now: now,
            configuration: configuration) == 0)
        let halfway = now.addingTimeInterval(12.5 * 60)
        let value = PomodoroEngine.progress(of: running, now: halfway, configuration: configuration)
        check("progress reaches halfway", abs(value - 0.5) < 0.0001)
        let done = now.addingTimeInterval(25 * 60)
        check(
            "progress saturates at the deadline",
            PomodoroEngine.progress(of: running, now: done, configuration: configuration) == 1)
    }

    private static func testSetTaskName() {
        let renamed = PomodoroEngine.setTaskName(idle(), taskName: "Ship it")
        check("the task name lands", renamed.state.taskName == "Ship it")
        check("renaming completes nothing", renamed.completed == nil)
    }

    // MARK: - Configuration

    private static func testConfigurationNormalization() {
        let wild = PomodoroConfiguration(
            focusMinutes: 0, shortBreakMinutes: 999, longBreakMinutes: -5, longBreakEvery: 0)
            .normalized
        check("focus clamps to the range", wild.focusMinutes == 1)
        check("short break clamps to the range", wild.shortBreakMinutes == 60)
        check("long break clamps to the range", wild.longBreakMinutes == 1)
        check("the cycle clamps to the range", wild.longBreakEvery == 1)
        check(
            "durations read the minutes",
            configuration.duration(of: .focus) == 1500 && configuration.duration(of: .longBreak)
                == 900)
    }

    private static func testConfigReanchor() {
        let shorter = PomodoroConfiguration(
            focusMinutes: 20, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 2)
        let longer = PomodoroConfiguration(
            focusMinutes: 30, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 2)
        let running = PomodoroEngine.start(idle(), now: now, configuration: configuration).state
        let twelveMinutesIn = now.addingTimeInterval(12 * 60)

        let shortened = PomodoroEngine.reanchor(
            running, from: configuration, to: shorter, now: twelveMinutesIn)
        check("a shortened focus keeps the elapsed time", shortened.remaining == 8 * 60)
        check(
            "a shortened focus moves the deadline",
            shortened.endsAt == twelveMinutesIn.addingTimeInterval(8 * 60))
        check("a re-anchored session keeps running", shortened.isRunning)

        let lengthened = PomodoroEngine.reanchor(
            running, from: configuration, to: longer, now: twelveMinutesIn)
        check("a lengthened focus keeps the elapsed time", lengthened.remaining == 18 * 60)
        check(
            "a lengthened focus moves the deadline",
            lengthened.endsAt == twelveMinutesIn.addingTimeInterval(18 * 60))

        let paused = PomodoroEngine.pause(running, now: twelveMinutesIn).state
        let pausedShorter = PomodoroEngine.reanchor(
            paused, from: configuration, to: shorter, now: twelveMinutesIn)
        check("a paused session follows the same rule", pausedShorter.remaining == 8 * 60)
        check("a re-anchored paused session stays paused", !pausedShorter.isRunning)
        check("a re-anchored paused session has no deadline", pausedShorter.endsAt == nil)

        let tiny = PomodoroConfiguration(
            focusMinutes: 1, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 2)
        let shrunk = PomodoroEngine.reanchor(
            running, from: configuration, to: tiny, now: twelveMinutesIn)
        check("shrinking below the elapsed time lands on zero", shrunk.remaining == 0)
        check("a zero remainder settles on the next tick", shrunk.endsAt == twelveMinutesIn)

        let refreshed = PomodoroEngine.reanchor(
            idle(), from: configuration, to: shorter, now: now)
        check("an untouched session takes the new duration", refreshed.remaining == 20 * 60)
        check("an untouched session stays idle", !refreshed.isRunning)
    }

    private static func testRestoredNormalization() {
        var corrupt = idle()
        corrupt.isRunning = true
        corrupt.endsAt = nil
        corrupt.remaining = 60
        corrupt.cycleIndex = Int.max
        let repaired = PomodoroEngine.restored(corrupt, configuration: configuration, now: now)
        check("a running session with no deadline is paused", !repaired.isRunning)
        check("a repaired session keeps its remainder", repaired.remaining == 60)
        check("restored cycle cannot overflow", repaired.cycleIndex == 12)

        var fresh = idle()
        fresh.isRunning = true
        fresh.endsAt = now.addingTimeInterval(400)
        let running = PomodoroEngine.restored(fresh, configuration: configuration, now: now)
        check("a running session keeps running", running.isRunning)
        check("restore recomputes the remainder", running.remaining == 400)
        check("restore keeps a valid deadline", running.endsAt == now.addingTimeInterval(400))

        var stale = idle()
        stale.isRunning = true
        stale.endsAt = now.addingTimeInterval(-30)
        let overdue = PomodoroEngine.restored(stale, configuration: configuration, now: now)
        check("an overdue session holds at zero until it settles", overdue.remaining == 0)
        check("an overdue session keeps running for the settle", overdue.isRunning)

        var overlong = idle()
        overlong.isRunning = true
        overlong.endsAt = now.addingTimeInterval(99 * 60)
        let capped = PomodoroEngine.restored(overlong, configuration: configuration, now: now)
        check("a remainder longer than the phase is capped", capped.remaining == 25 * 60)
        check("a capped remainder is re-anchored", capped.endsAt == now.addingTimeInterval(25 * 60))

        var brokenPause = idle()
        brokenPause.endsAt = now.addingTimeInterval(60)
        brokenPause.remaining = -5
        let paused = PomodoroEngine.restored(brokenPause, configuration: configuration, now: now)
        check("a paused session drops its deadline", paused.endsAt == nil)
        check("a negative remainder clamps to zero", paused.remaining == 0)
    }

    // MARK: - Stats

    private static func testStatsDayRoll() {
        let stats = PomodoroStats(day: "2026-11-10", completedFocusCount: 3, focusSeconds: 4500)
        check("the same day keeps its bucket", stats.rolled(to: "2026-11-10") == stats)
        let rolled = stats.rolled(to: "2026-11-11")
        check("a new day starts empty", rolled.completedFocusCount == 0 && rolled.focusSeconds == 0)
        check("the new day is stamped", rolled.day == "2026-11-11")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        check(
            "the day key is local-calendar derived",
            PomodoroStats.dayKey(for: date, calendar: calendar) == "2026-02-02")
    }

    private static func testStatsAccumulation() {
        let counted = PomodoroStats.empty.countingFocusCompletion(on: "2026-11-10")
        check("a completion counts", counted.completedFocusCount == 1)
        let timed = counted.addingFocusSeconds(90, on: "2026-11-10")
        check("focus seconds accumulate", timed.focusSeconds == 90)
        check("adding keeps the count", timed.completedFocusCount == 1)
        check(
            "zero adds nothing but still rolls the day",
            timed.addingFocusSeconds(0, on: "2026-11-10") == timed)
    }

    private static func testStatsCompletionDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11)) ?? now
        let yesterday = PomodoroStats(day: "2026-11-10", completedFocusCount: 2, focusSeconds: 4500)

        let recorded = yesterday.recording(
            .focus, at: midnight.addingTimeInterval(60), calendar: calendar)
        check("a focus completing after midnight counts on the new day", recorded.day == "2026-11-11")
        check("the completion count rolls with it", recorded.completedFocusCount == 1)
        check("the previous bucket's time is discarded", recorded.focusSeconds == 0)

        let sameDay = PomodoroStats(day: "2026-11-11", completedFocusCount: 1, focusSeconds: 60)
        let later = sameDay.recording(.focus, at: midnight.addingTimeInterval(7200), calendar: calendar)
        check("a same-day completion accrues", later.completedFocusCount == 2)
        check("a same-day completion keeps the time", later.focusSeconds == 60)

        let breakDone = sameDay.recording(
            .shortBreak, at: midnight.addingTimeInterval(7200), calendar: calendar)
        check("a break completion counts nothing", breakDone.completedFocusCount == 1)
    }

    private static func testFocusSecondsAccumulator() {
        var accumulator = PomodoroStats.FocusAccumulator()
        var total = 0
        for _ in 0..<50 {
            total += accumulator.record(0.5)
        }
        check("fifty half-second ticks add twenty-five seconds", total == 25)
        check("the fraction is carried, not counted", accumulator.pending < 1)
        check("a whole step lands at once", accumulator.record(2) == 2)
        check("a negative interval adds nothing", accumulator.record(-50) == 0)
    }

    // MARK: - Time text

    private static func testTimeText() {
        check("countdown shows 25:00", PomodoroTimeText.minutesSeconds(1500) == "25:00")
        check("countdown floors to the next second", PomodoroTimeText.minutesSeconds(1499.2) == "25:00")
        check("countdown crosses the minute", PomodoroTimeText.minutesSeconds(1498.9) == "24:59")
        check("countdown holds 0:01", PomodoroTimeText.minutesSeconds(0.4) == "0:01")
        check("countdown rests at 0:00", PomodoroTimeText.minutesSeconds(0) == "0:00")
        check("countdown clips below zero", PomodoroTimeText.minutesSeconds(-5) == "0:00")
        check("hours and minutes compress", PomodoroTimeText.hoursMinutes(4500) == "1:15")
        check("an hour is not padded", PomodoroTimeText.hoursMinutes(3600) == "1:00")
    }

    private static func testTaskBindingAndFreeFocus() {
        let taskID = UUID()
        var state = PomodoroEngine.focusTask(
            idle(), id: taskID, name: "Ship v2", now: now, configuration: configuration
        ).state
        check("focusTask binds id and starts running", state.activeTaskID == taskID && state.isRunning)
        state = PomodoroEngine.setTask(state, id: nil, name: "").state
        check("unbinding clears task without stopping focus",
              state.activeTaskID == nil && state.taskName.isEmpty && state.isRunning)
        let onBreak = PomodoroEngine.skip(state, now: now, configuration: configuration).state
        check("skip moves to break", onBreak.phase == .shortBreak)
        let refocused = PomodoroEngine.focusTask(
            onBreak, id: taskID, name: "Ship v2", now: now, configuration: configuration
        ).state
        check("focusTask from break switches back to focus",
              refocused.phase == .focus && refocused.activeTaskID == taskID && refocused.isRunning)
    }

    // MARK: -

    private static func check(_ message: String, _ condition: @autoclosure () throws -> Bool) {
        do {
            if try condition() { return }
        } catch {
            print("FAIL: \(message) (\(error))")
            failures += 1
            return
        }
        print("FAIL: \(message)")
        failures += 1
    }
}
