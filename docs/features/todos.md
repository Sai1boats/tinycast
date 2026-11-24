# Local Todos

## Invariants

- Each channel owns its projects and tasks in `~/Library/Application Support/<bundle-id>/todos.json`.
  Existing flat lists open in Inbox with their original IDs, titles and completion states. The first
  successful edit atomically writes the project document. Unreadable data is never overwritten.
- A project holds tasks with one level of subtasks. Moving or deleting a task includes its subtasks.
  Completing a task completes its subtasks. Reopening a subtask also reopens its parent.
- Pending local notifications belong to macOS and use each task's UUID. Startup and committed
  task changes reconcile future incomplete reminders with Notification Center. Renaming, moving,
  rescheduling, completion and deletion update the pending requests.
- Only explicitly saving a new reminder asks for notification access. Failed authorization leaves
  the editor intact. Scheduling failures after a successful save can be retried in the window.
- Drafts survive closing the window in the current process. Quitting waits for pending disk writes.

## Using the list

Open **Local Todos** in the launcher or assign a shortcut in Settings → Commands. The resizable
3-column Focus Panel opens at 1150 × 650 (sidebar 224pt, center task list, collapsible inspector
310pt). The sidebar provides smart views (**Inbox**, **Today**, **Scheduled**, **All**), colored
custom **Projects**, and an embedded **Focus Dock** when Pomodoro is enabled. Click the plus beside
**Projects** and enter its name in the dialog.

The bottom composer card supports task titles, priority cycling, and quick reminder presets
(**In 30 min**, **Tonight 18:00**, **Tomorrow 09:00**, **Next Monday**, or custom date/time). Hover
a task row to focus a Pomodoro on it (`⌘P`), add an inline subtask right beneath it, edit its title
in place, or open the context menu to move or delete it (with 5-second `⌘Z` Undo). Select any task
to edit its notes, priority, pomodoro estimate (`0–8`), reminders, and subtasks in the right
inspector. Completed root tasks collapse under **Completed (N)** at the bottom of the list.

Right-click a custom project and choose **Rename** to update its name and the project on its tasks and reminders.
Delete a custom project from its header or sidebar context menu. Confirmation moves its tasks and
subtasks to Inbox with their reminder times intact.

Select the **Time reminder** bell and choose a preset or future date and time before adding or saving
a task or subtask. Overdue incomplete reminders highlight in red. Delivery follows this Mac's
notification and Focus settings. Clicking a reminder opens its project and task. Clear the reminder
and save to cancel it.
