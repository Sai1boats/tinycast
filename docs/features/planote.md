# Planote

## Invariants

- Planote owns SwiftData and is the only database writer. Tinycast reads JSON snapshots and submits
  edits through the Planote bridge; it never opens Planote's database.
- Root search indexes note titles only, using the ordinary fuzzy and Chinese transliteration ranking.
  Notes have their own `AppEntry.Kind.planoteNote`, section and Planote settings owner.
- Disabling note search removes its launcher entries and hides its editor. Stopping the service also
  prevents todo commands from automatically relaunching Planote. Saved snapshots remain readable.
- An edit compares the published content version before changing title or literal Markdown. External
  edits and deleted notes are rejected, never silently overwritten. Attachments remain untouched.
- A result is published only after the store flush and snapshot publication. Requests are identified
  by UUID; persisted receipts prevent a replay from overwriting later edits.
- Unsaved drafts live in Tinycast's bundle-specific Application Support, outside caches and backups.
  Closing, changing notes and quitting flush the active draft. Failed saves retain the draft; a dirty
  note blocks switching until saved or explicitly reloaded with a recovery copy.

## Search and editing

Settings → Planote controls title search and the background service. Opening the launcher refreshes
its small title index off-main and starts the service if permitted. Clicking a result opens a floating
660 × 580 panel (minimum 440 × 350). It reuses Notes' TextKit 2 Markdown editor, undo, find, list editing,
formatting shortcuts and literal-source semantics. The title is editable. Changes autosave after
600 ms; ⌘S saves immediately, and ⌘W/Escape hide the panel while preserving the draft.

A clean note reloads on reopening; a dirty one remains local. Conflicts offer **Keep Draft & Reload**,
which archives a readable Markdown copy under **Drafts** before loading the latest published note.
Images and other attachments are preserved and their presence is indicated; **Open Planote** provides
its full attachment UI. The editor can also show literal Markdown without changing content.

## Service and storage

The existing todo bridge directory contains a `Notes/` child:

```
Notes/snapshot.json          schemaVersion 1, note title/version/date/attachment-count summaries
Notes/notes/<uuid>.json      one note's summary and literal Markdown
Notes/commands/<uuid>.json   request, expectedVersion, title and Markdown
Notes/results/<uuid>.json    saved note or explicit error, keyed by request UUID
```

The version is a SHA-256 digest including title, Markdown, modification timestamp and attachment
count. Trashed notes are excluded. The index never includes full note bodies. Private recovery files
live under `AppPaths.applicationSupport()/PlanoteDrafts` and never share state across bundle IDs.

Planote's service entry point uses an accessory NSApplication directly: no SwiftUI scene, window,
editor, Dock icon or frontmost activation is created. SwiftData, reminder delivery and
the two bridges remain alive. Opening Planote creates its workspace and starts automatic sync on
demand in the same process. Minimal mode does not start network sync or request Keychain credentials;
background sync credential reads run off-main so a system authorization prompt cannot stall the bridge.
Stores expose content revisions so idle ticks do not encode the complete data set. Stop Service uses
normal application termination, flushing Planote's pending writes; it also closes any Planote window.

`planote.notesEnabled` and `planote.serviceEnabled` participate in the opt-in settings.json mirror;
they are intentionally local and excluded from settings backups. The service-enabled flag allows
on-demand starts; it is not a login item. A stopped service stays stopped across Tinycast restarts.

## Verification

`planote-test` covers title-index reads, Unicode Markdown, offline drafts, recovery, external-edit
conflicts and acknowledged autosave. `planote-ui-test` renders the shipped editor in both appearances
and supported sizes, edits through its native text view and checks recovery-file persistence.
Planote's `NoteBridgeTests` checks persisted save, conflict rejection, replay, deletion and validation
against an isolated in-memory SwiftData repository. The existing todo tests cover regression behavior.
