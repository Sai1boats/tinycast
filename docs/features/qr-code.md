# QR Code

The built-in **Generate QR Code** command opens a native palette screen with a content field,
a chronological history list and a QR preview. It is searchable as `QR`, `QR code` and `二维码`,
and supports the ordinary command aliases, visibility and global hotkeys in Settings → Commands.

## Invariants

- Generation is local, using Core Image. No extension runtime, network or third-party dependency.
- Return generates from the content field; selecting history never changes that field or regenerates
  an entry. The field follows the palette's single-line paste normalization and IME handling.
- Empty/whitespace-only content is rejected. Input is limited to 2,000 UTF-8 bytes, with exact
  non-empty content preserved, including leading and trailing spaces.
- PNG output is black on opaque white in both appearances, with medium error correction,
  a four-module quiet zone and integer module scaling.
- Only successful generation and persistence add an entry. Identical content moves to the top;
  history keeps at most 200 entries. Viewing, copying and saving never add records.
- History is a private per-channel file in Application Support: `<bundle-id>/qr-code-history.json`.
  It is not included in settings backups. An unreadable file is reported and never overwritten.
- `AppCore` owns the history store and coordinator. History loads on first use; generation and file
  I/O run off-main. Mutations are serialized by the coordinator, and quitting awaits pending writes.
- A preview task follows the selected entry and checks cancellation before publishing its image.
  A completed generation cannot reset selection in another palette navigation session.

## Interaction

Type a URL or text and press Return (or use the **Generate QR Code** footer button). The new entry
appears first and its QR code fills the right pane. Up/Down and clicking browse history.
**Copy Image** and **Save Image…** are available below the preview and in the Actions menu.
Command-Return copies the selected image. Control-X or **Delete Entry** removes one history item.
Double-clicking a history row copies its image. Export uses a native save panel and writes PNG.

`qr-code-test` decodes generated images with Vision, including Unicode and maximum-length text,
and exercises capacity, deduplication, disk round trips, corrupt history, write errors and navigation
changes during generation. `qr-code-ui-test` renders the native split view in both appearances and
all interface sizes; optional PNG output uses `TINYCAST_QR_PREVIEW_DIRECTORY`.
