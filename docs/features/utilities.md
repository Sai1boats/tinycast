# Native utilities

Three launcher commands — **JSON Tools**, **Timestamp Converter** and **Currency Converter** — open
three independent native, resizable windows with no tool switcher. Each window keeps its own identity and frame; opening one never replaces another. They are regular commands, so launcher visibility,
aliases and global shortcuts are configured in Settings → Commands. Existing calculator conversions
and Quick Translate are unchanged.

All three windows hide the native traffic-light buttons. A close button in the upper-right corner
closes only its own tool; Escape also closes it. Window dragging and resizing remain available.

## Invariants

- `AppCore` owns `UtilityCoordinator`; views receive it through the environment. Tool state stays in
  memory, and no input/output is written to settings, history or disk. Clipboard reads and writes only
  happen through explicit buttons.
- JSON transformations execute off-main. Source changes and window closure cancel the task and advance
  its generation; late results cannot replace a newer input's output. Parsing is bounded to 1 MiB input,
  128 container levels and 4 MiB formatted output.
- `Model/` imports Foundation only and takes time zones, dates and rate snapshots as arguments.
- Currency uses the existing `CurrencyRateStore`, not another network client or cache. Refresh is
  coalesced with the calculator's scheduled refresh, and stale/cancelled fetches cannot apply after stop.
  Failed requests leave available data usable; incomplete fiat-only responses follow the existing
  calculator policy. The UI names the feed, its download time, and data older than 24 hours.

## JSON

The JSON window opens at 1100 × 620 points, with 12-point insets on each side of the draggable
split divider. Its independent frame is saved as `JSONTool`.

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

Input uses a decimal point and at most 28 digits, with no thousands separators. Decimal arithmetic
converts through the snapshot's base currency and rounds to at most eight fractional digits with
banker's rounding. Copy Result copies only the numeric amount. Same-currency conversions need no rate;
missing rates and malformed input show a message instead of a fabricated result. Currency menus expose
available feed codes, including crypto when available. Rates are cached reference data, not an
executable quote, and exclude fees and spreads.

## Verification

`utilities-test` compiles the shipped pure sources and covers exact large-number preservation, strings,
escapes, fragments, malformed and oversized JSON, nesting/output bounds, negative timestamps, seconds
versus milliseconds, round trips, invalid dates, DST gaps/folds, Decimal conversions and missing rates.
Manual checks cover editor selection/copy, window resizing, clipboard actions and a live feed refresh.
