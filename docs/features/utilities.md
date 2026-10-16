# Native utilities

Nine launcher commands — **JSON Tools**, **Timestamp Converter**, **Currency Converter**, **URL Encoder / Decoder**,
**Base64 Encoder / Decoder**, **UUID Generator**, **Hash Generator**, **JWT Viewer** and **Text Diff** — open
independent native, resizable windows with no tool switcher. Each window keeps its own identity and frame; opening one never replaces another. They are regular commands, so launcher visibility,
aliases and global shortcuts are configured in Settings → Commands. Existing calculator conversions
and Quick Translate are unchanged.

All utility windows hide the native traffic-light buttons. A close button in the upper-right corner
closes only its own tool; Escape also closes it. The small × has no persistent fill and reveals a
rounded hover/press background. Window dragging and resizing remain available. Every operation button
is neutral at rest, including the first; keyboard defaults do not carry selected styling.

## Invariants

- `AppCore` owns `UtilityCoordinator`; views receive it through the environment. Tool state stays in
  memory, and no input/output is written to settings, history or disk. Clipboard reads and writes only
  happen through explicit buttons.
- JSON transformations execute off-main. Source changes and window closure cancel the task and advance
  its generation; late results cannot replace a newer input's output. Parsing is bounded to 1 MiB input,
  128 container levels and 4 MiB formatted output.
- `Model/` uses Foundation and Apple's CryptoKit, with no UI or network access. Time zones, dates,
  rate snapshots and UUID creation are injected.
- Developer tools run entirely locally. Each open tool has its own `DeveloperToolSession`, owned by
  `UtilityCoordinator`; closing it cancels work and releases its input and result. Encoding, hashing,
  token inspection and diffing execute off-main with cancellation and generation checks. Input or
  option changes clear the old result. UUID batches run synchronously, capped at 1,000 identifiers.
- Currency uses the existing `CurrencyRateStore`, not another network client or cache. Refresh is
  coalesced with the calculator's scheduled refresh, and stale/cancelled fetches cannot apply after stop.
  Failed requests leave available data usable; incomplete fiat-only responses follow the existing
  calculator policy. The UI names the feed, its download time, and data older than 24 hours.

## JSON

All nine utility windows use the [Focus Panel design](../ui.md#focused-utility-windows):
760 × 740 points initially, 680 × 600 minimum, a compact title, 20-point aligned outer insets,
inset editor headings and one bottom action group. JSON's input and result stack vertically with a
draggable divider; its independent frame is saved as `UtilityFocus-json`.

The parser validates JSON grammar while keeping original string and numeric tokens. Formatting adds
2-space indentation; compression removes insignificant whitespace. Neither converts through floating
point or a dictionary, so large integers, decimal spellings, key order and duplicate keys are preserved.
Malformed input reports a UTF-8 byte position. Unescape decodes exactly one JSON string layer, accepting
a quoted JSON string literal or unquoted escaped text. It never blindly removes backslashes. Its result
may be ordinary text; use **Use Result as Input** before another transformation.

## Timestamps

Both directions use the selected time zone. Timestamp input accepts seconds with up to three decimal
places or integer milliseconds, including negative values. Auto treats magnitudes at least 100000000000
as milliseconds; small millisecond values require selecting that unit explicitly. Supported dates are
years 0001–9999. Results include seconds, milliseconds, the selected-zone date and UTC, each copyable.
The timezone control, two input cards and one result card share aligned edges; both conversion
operations and Use Current Time live in the bottom action bar. The content scrolls at smaller heights.

Date input is strictly `yyyy-MM-dd HH:mm:ss` or `yyyy-MM-dd HH:mm:ss.SSS`. Invalid dates and DST gaps
are rejected. Repeated wall-clock times during a DST fold are rejected rather than silently selecting
one instant; use UTC for those. **Use Current Time** injects the current instant from the coordinator.

## Currency

Input converts immediately while typing. Examples include `100￥`, `$200`, `CNY100`, and `100 CNY to JPY`.
Currency symbols may precede or follow the amount. `$` means USD and `￥`/`¥` mean CNY; use `JPY`
for Japanese yen. ISO codes and supported currency aliases are case-insensitive. A bare amount uses
the default-currency picker. A query target (`to`, `→`, `->`, `兑换`, `换成`) overrides the target picker.
Without a target, cards show CNY, USD, EUR, GBP, JPY, HKD, CAD, AUD, SGD and CHF except the source.
Each card is individually copyable, and missing quotes show an unavailable state.
Currency controls, the amount card and the scrolling result grid use the same Focus Panel insets and
card surface; Refresh Rates stays in the bottom action bar above the feed timestamp and source.

Input uses a decimal point and at most 28 digits, with no thousands separators. Decimal arithmetic
converts through the snapshot's base currency and rounds to at most eight fractional digits with
banker's rounding. Copy Result copies only the numeric amount. Same-currency conversions need no rate;
missing rates and malformed input show a message instead of a fabricated result. Currency menus expose
available feed codes, including crypto when available. Rates are cached reference data, not an
executable quote, and exclude fees and spreads.

## Offline developer tools

The six developer commands are regular built-in commands, with visibility, aliases and hotkeys in
Settings → Commands. Their titles and search keywords also find them in Chinese; SHA-256 and MD5 find
Hash Generator, Base64url finds the codec, and Bearer finds JWT Viewer. No permission is requested,
no input is fetched automatically, and only explicit clipboard buttons read or copy text. Command-Return
runs the primary operation; Command-Shift-C copies its result (the payload in JWT Viewer).

URL and Base64 windows stack input above result in a draggable vertical split. URL Component encodes only RFC 3986
unreserved characters verbatim, for use as a value rather than as an entire URL. Form Value follows
the form-urlencoded alphabet: alphanumerics and `*-._` remain literal, spaces become `+`, and `~` is
escaped. Decoding that mode treats `+` as a space. Decode removes exactly one encoding layer and rejects
malformed escapes or invalid UTF-8. Base64 supports standard padded encoding and unpadded Base64url;
decoding permits whitespace and correctly padded Base64url, but rejects mixed alphabets, incorrect
padding, noncanonical trailing bits and non-UTF-8 bytes. Each input is capped at 1 MiB of UTF-8.

UUID Generator produces random version 4 UUIDs, one per line, with a count from 1 to 1,000 and optional
uppercase and hyphens. Hash Generator hashes exact UTF-8 input, preserving spaces and line endings,
with SHA-256, SHA-384, SHA-512, SHA-1 or MD5 through CryptoKit. The maximum text size is 1 MiB.

JWT Viewer accepts a three-part compact token or a `Bearer ` prefix. It formats header and payload
objects through the existing token-preserving JSON parser, keeping large numbers, key order and
duplicate keys intact. It exposes the signature for copying but never verifies it, downloads keys or
labels a token authentic. `iat`, `nbf` and `exp` numeric claims within years 0001–9999 display as UTC
times; booleans, strings and unrepresentable times remain visible in the payload without derived dates.
The claimed time status is evaluated when Inspect is pressed, against an injected clock snapshot.
Encrypted five-part tokens and invalid JSON objects are rejected. Input and JSON nesting/output bounds
are the existing Base64 and JSON limits.

Text Diff compares exact lines through Swift's `CollectionDifference`, capped at 128 KiB and 1,000
lines per input. Its split view holds editable originals above a selectable diff. Insertions have a
green `+` prefix and deletions a red `-` prefix; unchanged lines have two spaces. CRLF, CR and absent
final newline markers make otherwise invisible ending differences explicit. Copy Diff copies this
human-readable comparison, not a patch file. Swap Texts reverses the inputs and clears the result.

## Verification

`utilities-test` compiles the shipped pure sources and covers exact large-number preservation, strings,
escapes, fragments, malformed and oversized JSON, nesting/output bounds, negative timestamps, seconds
versus milliseconds, round trips, invalid dates, DST gaps/folds, Decimal conversions and missing rates.
Manual checks cover editor selection/copy, window resizing, clipboard actions and a live feed refresh.

`developer-tools-test` compiles the shipped models and session. It covers Unicode URL round trips,
RFC Base64 vectors, malformed encodings and padding, binary decode rejection, UUID bounds and formats,
known hash vectors, JWT number preservation and time boundaries, reconstructed diff inputs including
line endings, worst-case line limits, cancelled tasks and superseded results. Manual checks cover all
six launch commands, independent windows, keyboard actions, bilingual labels, native text editing,
split resizing, copying results and closing during processing.

`developer-tools-ui-test` mounts all nine shipped views in real AppKit windows. It checks shared editor
edges and native timestamp/currency input alignment at both default and minimum sizes in Light and Dark,
diff colors, independent windows, retained
sessions on view disappearance and fresh sessions after close/reopen, with clipboard and network
effects replaced by in-memory stubs. Set `TINYCAST_TOOL_PREVIEW_DIRECTORY` to save native PNGs of
fixture contents for visual comparison.
