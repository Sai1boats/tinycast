# Pomodoro

A native pomodoro timer with an always-on-top desktop widget. The widget is one borderless,
non-activating `NSPanel` at `.floating` level — dragged from anywhere on its background, joining every
space, remembering its frame — with two faces on one glass card. The collapsed face is 228×66
(`Theme.Size.pomodoroCollapsed`): the phase badge, the countdown, today's pomodoro count and one
hairline progress rail. Hovering swaps the count for the primary action (Start, Pause or Resume) and
Skip; a click expands. The expanded face is 312×360 (`Theme.Size.pomodoroExpanded`) and runs as a small
Focus Panel console:
the cycle title (Focus · 1 / 4), a large countdown, the task name, the day's stats and one bottom
action group.

## Invariants

- **`Model/` is pure Foundation and takes the current instant as a parameter.** `PomodoroPhase`,
  `PomodoroConfiguration`, `PomodoroState`, `PomodoroEngine`, `PomodoroStats` and `PomodoroTimeText`
  import nothing but Foundation; every engine decision receives `now`. `pomodoro-test` compiles these
  sources and pins the state machine.
- **`cycleIndex` advances only when a focus phase finishes by its deadline.** A skip reports no
  completion, does not count and does not advance the cycle. A passed deadline settles at once, one
  phase per call: oversleeping settles a single phase, and the next one is anchored to the current
  instant rather than backdated. A paused phase whose remainder reached zero is completed by the next
  resume — one phase, counted and announced at that instant — never started as a zero-length phase. A
  long break returns `cycleIndex` to zero.
- **Focus time accrues from the 500 ms tick and before session actions.** `PomodoroStats.FocusAccumulator` carries the sub-second
  remainder so a whole second is never truncated away, and one tick credits at most two seconds, so a
  suspended Mac is not handed hours of focus time. Credit stops at the phase deadline and is limited
  to the current day; fractional carry resets when the day changes.
- **The phase hue is a mark colour.** It tints the badge dot and the progress rail only — never a
  surface.
- **Off means no entry point, no tick and no widget.** With `pomodoroEnabled` off the two commands
  are hidden from the launcher, the store's tick loop stops and the panel is put away. Re-enabling it
  restarts the stopped loop even when the configuration is unchanged. Configuration edits while off
  cannot restart the loop or settle a phase.
- **Settings reproject onto the store immediately.** `AppCore.track` watches `pomodoroEnabled` and
  `pomodoroConfiguration`, so a change lands in `PomodoroStore` — and the running session — without a
  restart. A duration change re-anchors the current phase, running or paused, keeping the time already
  spent: the new remainder is the new duration minus that elapsed part, and a zero remainder settles on
  the next tick.
- **Phase completions announce through the MessageHUD.** Focus completion shows success
  "Focus session complete."; a break ending shows neutral "Break's over." Never `NSAlert`, never a
  system notification.
- **The session persists in `Application Support/pomodoro-state.json`.** State and the day's stats
  are one JSON payload; a day change discards the old bucket rather than merging into it. Focus time is
  flushed about every 30 seconds while ticking and on pause, disable, phase change and configuration
  change and app termination, and task-name edits coalesce into one write that still flushes on those paths. A restored
  session is repaired first: a run without a deadline comes back paused, a remainder never outlives its
  phase, and an overdue deadline settles one phase on load when enabled. The repaired state is saved
  immediately so another launch cannot settle the same persisted phase again. Settings live in `AppSettings` with a
  `pomodoro.*` mirror in settings.json, and `pomodoroEnabled` plus the four duration settings ride
  settings backups.
- **The day bucket follows the system day.** The stats roll on the calendar-day-change notification
  (and on a time-zone change), so the widget never shows yesterday's count while the timer is paused,
  on a break or switched off. Nothing rolls the day from a view body.
- **Two launcher commands, owned by Settings → Pomodoro.** `Show Pomodoro` (`command:show-pomodoro`)
  toggles the widget; `Start Pomodoro` (`command:start-pomodoro`) starts or resumes the session and
  keeps the widget in view. Both follow the feature switch.
- **Free Focus and optional Local Todos binding.** `PomodoroState.activeTaskID` is optional; the
  timer runs freely with no task bound (or when unbound via `unbindTask()` without interrupting the
  countdown). Binding a task from Local Todos (`focusTask(id:title:)`) updates the active task and
  reports focus completions through `onFocusCompleted` so `AppCore` credits the task's completed
  pomodoro count and focused minutes.

## Window behaviour

`PomodoroWidgetPanel` is borderless and non-activating (`nonactivatingPanel`), floats at `.floating`,
and is moved by its background. `isMovableByWindowBackground` is off: the hosting view eats every
background press, so a feature-owned drag surface (`PomodoroWidgetDragSurface`) sits in front of the
scrim and glass but behind the content and moves the panel itself. Every decorative label is
`allowsHitTesting(false)` so a press on it reaches that surface; real controls still win their own
clicks. A press that never moves more than a few points is a click: on the collapsed face it expands,
and on the expanded face it does nothing. The content host accepts first mouse, so the first click on
the widget acts even while Tinycast is inactive — needed because the header glyphs and the hover
controls must respond in one press. Escape and the expanded face's quiet × only collapse the card.
Hiding is its own glyph: `eye.slash` sits beside the × on the expanded header and puts the widget
away. Resizing keeps the top-left corner put, so
the card grows and shrinks downward in place. The frame autosaves under the `"Pomodoro Widget"` name; on a first run the collapsed face
seats at the top right of the visible screen, and a frame a display change left outside every screen
is pulled back inside the visible area before it is shown.

## Settings

Settings → Pomodoro holds the enable switch (on by default), the four durations and the two commands;
the durations section greys out with the switch. Focus, Short Break, Long Break and Pomodoros per
cycle default to 25 / 5 / 15 / 4 and live in 1–180 / 1–60 / 1–60 / 1–12.
`PomodoroConfiguration.normalized` clamps any configuration the store takes, and a settings.json
value outside its range is rejected rather than applied.

## Testing

`./Scripts/run-tests.sh pomodoro-test` compiles `Tinycast/Features/Pomodoro/Model/` and pins the
engine against a fixed clock: the start/pause/resume/toggle transitions, focus → short break, a full
cycle to the long break and back to a fresh one, skip semantics (no completion, the cycle untouched, a
skipped break returning to focus), oversleep settling one phase anchored at wake while a paused
session never settles, a depleted paused phase completing on resume, progress saturation,
configuration clamping, the elapsed-preserving re-anchor for a running and a paused phase, restoring a
corrupt or overdue session, the stats day roll that discards the old bucket, a completion counting on
the day it completes, the sub-second focus-seconds carry, and both time-text forms. The harness also compiles the store and uses an injected clock and temporary files to check
action-time accounting, deadline clipping, disabled configuration changes and repeated restoration.
Calendar notification delivery and the real tick scheduling still require manual checks.

## Non-goals for v1

System notifications (`UNUserNotification`), auto-pause when the user leaves the Mac, statistics
history charts, calendar integration, and a menu bar item of its own.
