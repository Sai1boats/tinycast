# Todos

A native todo list inside Tinycast, backed by the Planote app's SwiftData tasks. Planote remains the
single owner of the data; Tinycast reads a published snapshot and queues JSON commands that Planote
applies. The window is a sibling surface like Notes: one floating panel, opened from the launcher or a
hotkey, with an in-panel task sheet for adding, editing and annotating tasks.

## Invariants

- **Planote owns the data and is its single writer.** Tinycast never opens the SwiftData store. It reads
  `snapshot.json` and writes command files; every mutation is applied by the running Planote process
  through its existing `TodoStore`, so reminders, recurrence and persistence keep working untouched.
- **The bridge runs headless.** A write with no Planote running launches the app with
  `--todo-bridge-only`: no window, no Dock icon, no activation. A dedicated accessory NSApplication starts the bridge from
  `applicationDidFinishLaunching`, without constructing SwiftUI scenes or windows. Opening Planote later hands the same process over to its visible window; the bridge never stops.
- **The bridge is the only contract between the apps.** Its wire schema is versioned independently of
  either app and is append-only; this doc and Planote's `docs/TODO_BRIDGE.md` describe the same v1.1.
  A field is never renamed or repurposed.
- **Off means no entry point and no work.** With `todosEnabled` off the commands are absent from the
  launcher, the window cannot show, and nothing polls the bridge directory.
- **Polling happens only while the window is visible.** Showing the window starts a one-second refresh
  loop; hiding it cancels the loop. There is no background sync, file watcher or timer for this feature.
- **The snapshot is the read model, never the write model.** Rows render `snapshot.json`. An edit starts
  from the current snapshot, sends a command, and only then re-reads the published snapshot. Optimistic
  rows are not invented.
- **Tinycast edits title, Markdown notes, due date, board section, label, subtasks and completion.**
  Notes are the Markdown source (`notesMarkdown`); Planote derives the plain-text field from it exactly as
  its own editor does, and keeps a task's legacy rich text and images untouched. Start dates, images,
  reminder settings and recurrence stay read-only here and are preserved by Planote's update path.
- **Commands are desired-state and replay-safe.** Create carries the client-generated task UUID, update
  carries a full editable projection, and completion carries the desired boolean. Replaying any command
  changes nothing twice, so a crash between applying and acknowledging cannot duplicate a task, and a
  timed-out create keeps its id across retries.
- **A command is consumed only after its result is written.** Planote writes `results/<request-id>.json`
  before deleting the command; Tinycast waits for the result and the snapshot revision it names.
- **Failure is inline and non-destructive.** There is no delete in v1. Offline, not-installed, launch
  timeout, persistence failure and validation errors are shown in the window (or the initiating view);
  no `DialogController` sheet is raised for a routine mirror failure.

Settings → Planote can stop the shared background service. While stopped, todo writes are refused
until Start Service is chosen; cached tasks remain readable. See [planote.md](planote.md).

## Storage and protocol

Both apps are unsandboxed, so the bridge is a shared directory owned by Planote:

```text
~/Library/Application Support/Planote/TodoBridge/
  snapshot.json      tasks (incl. notes + notesMarkdown), labels, sections, revision, generatedAt
  status.json        pid, startedAt, lastHeartbeatAt, revision; deleted on clean quit
  commands/          Tinycast writes <epoch-millis>-<request-id>.json atomically
  results/           Planote writes <request-id>.json atomically, prunes after 10 minutes
```

All files are UTF-8 JSON with ISO 8601 dates and sorted keys. Tinycast's planner lives in
`Features/Todos/Model/` (`TodoBridgeProtocol`, `TodoBridgePaths`, `TodoBridgeFileStore`,
`TodoEditorDraft`, `TodoListModel`) and imports only Foundation; `Features/Todos/Service/TodoBridgeClient`
is the AppKit/effect half that resolves and launches Planote, writes commands and waits for results.

Liveness is the `status.json` file's modification date within ten seconds. A snapshot without a live
status is shown as cached: the list still renders, edits are queued, and the banner names the state.

### Commands

| Kind | Payload | Planote behaviour |
| --- | --- | --- |
| `create` | task id, title, dates, section, label, subtasks, optional `notesMarkdown` | Builds a `TodoItem` with the same bucket and notes rules as its own editor, upserts by id |
| `update` | the same projection | Starts from the stored task and overwrites only the projection; omitted `notesMarkdown` preserves notes/rich text/images, `""` clears the note, text is trimmed and stored as Markdown with its plain text derived |
| `setCompleted` | task id, desired boolean | Calls `toggle` only when the value differs, preserving recurring-task behaviour |

Errors are coded `invalidCommand`, `invalidTitle`, `taskNotFound`, `persistenceFailed` or `internal`, and
carry a user-readable message. A result always carries the snapshot revision that includes the change.

## The window

`TodosPanel` is a titled, resizable, non-activating panel with its own behind-window HUD material.
The title is drawn in SwiftUI inside a 52-point band, centred on the window; AppKit draws and seats the
traffic lights (`todosTrafficLightInset`), and the band drags the window. Its trailing end is one quiet
ink capsule: a connection dot and compact Refresh. The dot exposes its status through a tooltip and
accessibility label. The panel keeps its frame under the `"Todos Window"` autosave name and seats
itself at the top right of the visible screen on a first run.

The Task Sheet design uses one 28-point inset (`Spacing.xxxl`). A rounded 22-point “My Todos”
heading leads the list, with the open count on its trailing edge. Planote board sections retain their
order, inbox first, under compact semibold headings. Rows pair a separate completion control with a
14-point task title and a second line of due date, named label and subtask count. Notes stay in the
editor, leaving the list easy to scan. An overdue glyph accompanies the date; hover is the only row
fill. Empty and unavailable states remain inline, and connection failures leave cached rows visible.

Editing replaces the list inside the same panel. A quiet back control precedes the rounded 22-point
editable title and a 118-point Markdown text editor. Both sit directly on the panel material. A compact
property block, ruled only at its top and bottom, holds the optional due date, board section and label.
The date switch preserves the existing enable/disable behavior and reveals a full date/time picker.
Subtasks follow as plain editable rows, with separate complete/remove actions and a final add row.
There are no nested form cards. Content scrolls at the minimum 420×480 size; the footer stays visible.
Opening the list leaves its controls unfocused until keyboard or pointer navigation. Existing tasks
open without selecting their title; only a new task automatically focuses its empty title.

`TodoStatusCaption` shows connection status on the list and draft guidance in the editor, replaced by
progress during a command. The list footer ends in three equally sized icon buttons: Completed,
Open Planote and New Todo. Each has a tooltip and accessibility label; the completed filter uses a
filled checkmark when active. Editing ends in Cancel and Save Changes (Create Todo for a new task),
using feature-local capsule buttons. An empty
title or an in-flight command disables save. Escape cancels the editor before hiding, and neither hide
nor a failed save discards the draft. Text follows the shared ink ramp. The local HUD backdrop blurs
behind the window under a light adaptive slate tint, remaining active when the panel loses focus.
Typography uses a compact scale: headings 22, task rows 14, notes/subtasks 13, properties/actions 12
and metadata/status 11 points. These fonts, backdrop tints, geometry and action ink live in `Theme`.

### Focused UI verification

`./Scripts/run-tests.sh todos-bridge-test` and `./Scripts/run-tests.sh todos-ui-test` check the bridge
model and the shipped native list/editor views. The UI harness reads a private temporary snapshot, never the user's Planote data.
It checks list/edit/create in Dark and Light at 480×700 and 420×480, title/Markdown bindings, empty-title
save validation, hide/cancel draft behavior, independent completion/open actions, native input font
sizes, behind-window material configuration and initial/reopened keyboard focus. Set
`TINYCAST_TODO_PREVIEW_DIRECTORY` to export the twelve native view PNGs for inspection.

## Commands and settings

`Show Todos` (`command:show-todos`) toggles the panel and `New Todo` (`command:create-todo`) opens it in
the editor. Both are owned by the Todos settings pane, so they follow the feature switch, can be aliased,
pinned, hidden and given hotkeys like any other launcher command.

The pane holds the enable switch and a live status block: whether Planote is installed and running, the
bridge directory, the last heartbeat and the last error. Its subtitle states that Tinycast starts Planote
in the background when needed. The switch ships on, so the feature is usable without a trip to Settings;
turning it off removes both commands, closes the panel and stops polling. `todos.enabled` and the
per-command visibility list (`todos.commands`) ride the opt-in settings file; `todosEnabled` rides
settings backups, since it grants no permission class.

## Failure modes

| State | Window | Next write |
| --- | --- | --- |
| Planote not installed | empty or cached list, banner names the missing app | refused with the install hint; no command written |
| Planote installed, not running | cached snapshot, `Offline` status | launches Planote headless, then applies; queued on timeout |
| Planote headless, Open Planote | hands the running process over to its visible window | bridge keeps running; no relaunch, no store reopen |
| Command rejected | inline error above the action bar | snapshot refreshed; the draft is kept for retry |
| Persistence failed in Planote | inline error names Planote's message | retry after Planote's own save recovery |

## Non-goals for v1

Deleting tasks, editing images/start dates/reminder settings/recurrence, creating or renaming labels and
board sections, background sync while the panel is hidden, and any iCloud or network transport.
