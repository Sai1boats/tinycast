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
project window opens at 1150 × 650. Click the plus beside **Projects** and enter its name in the dialog. The new-task field stays
at the bottom of the project pane while its list scrolls. Use a task's plus button to add a subtask, its pencil to edit the row in place, or its menu to
move or delete it. Expand the task to see its subtasks and individual reminders.

Right-click a custom project and choose **Rename** to update its name and the project on its tasks and reminders.
Delete a custom project from its header or sidebar context menu. Confirmation moves its tasks and
subtasks to Inbox with their reminder times intact.

Select the **Time reminder** bell and choose a future date and time before adding or saving a task or subtask.
Delivery follows this Mac's notification and Focus settings. Clicking a reminder opens its project
and task. Clear the reminder checkbox and save to cancel it.
