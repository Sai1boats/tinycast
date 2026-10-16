# Quick Translate

A native, resizable floating panel that translates with Baidu General Translation first and Apple's
on-device translator whenever Baidu cannot answer. It is separate from the Apple-powered Quick Action.
**Quick Translate** opens an editable source; **Translate Selected Text** reads the app behind the
palette and translates immediately. Both commands are in Settings → Commands, where shortcuts and
aliases can be assigned.

## Invariants

- `AppCore` owns `TranslationCoordinator`. Views receive it through the environment. Closing the panel
  or terminating cancels owned work; request generations and panel-session identities reject late
  results — from Baidu, from any chunk of a long text, and from the Apple fallback alike.
- **Baidu is always asked first when credentials exist.** Apple answers only when Baidu has no
  credentials, the text is over the long-text limit, or a request fails for a reason another
  translator could fix: authentication, rate limit, balance, an unavailable service, a malformed
  reply or a network error. Empty input, an invalid language choice and cancellation never fall back.
  `BaiduTranslation.allowsFallback(after:)` is that whole rule, pure and tested.
- A fallback always says so: the footer names Apple Translation and the reason Baidu did not answer.
  When Apple fails too, both reasons are reported together.
- `BaiduTranslationService` uses a private ephemeral URL session without URL cache, cookies or credential
  storage. Requests are HTTPS POST with a 15-second timeout and no automatic retries.
- APP ID and secret are stored together in the channel-specific `baidu-translation` Keychain scope.
  They are never settings-file or backup entries. No credentials or translations are logged.
  Missing credentials never block the panel; the footer offers **Set Up Baidu…** instead.
- Source, result, language selections, pin state, text size, the bilingual toggle and the last 20
  successful translations are session-only. History never goes to disk. Editing source or language
  cancels and invalidates the previous result, including a long text still arriving chunk by chunk.
- The destination application is captured before opening the panel, and never becomes Tinycast itself.
  Selected-text capture and delivery use the existing permission-checked text-injection services.
  Failed delivery copies the translation and reports it; no unrequested paste occurs.
- `Model/` stays Foundation-only. Language codes, chunking, paragraph alignment, the fallback rule,
  UTF-8 limits, response decoding and bounded history compile directly in `translation-test`.

## Long text

Baidu takes at most 6000 UTF-8 bytes per request. `TranslationChunks.split` groups whole lines under
that limit, in reading order, so chunks rejoin to the exact source. A single line longer than the limit
breaks after a sentence (`。！？；.!?;`) where it can, otherwise between grapheme clusters; such a line
then reads as several paragraphs. Up to ten chunks (60000 bytes) go to Baidu, one after another, 1.1 s
apart because Baidu's standard tier answers one request per second. Each chunk after the first reuses
the languages the first resolved, so a mixed document is not split between two targets. Longer text
goes straight to Apple.

Results are paragraphs, not one string: `TranslationResult.paragraphs` pairs every non-blank source line
with Baidu's translated line and keeps blank lines as blank paragraphs, so the translation keeps the
source's paragraph breaks. When Baidu returns a different number of lines, its own `src`/`dst` pairs are
kept instead. Apple translates the same lines as one batch (`TextTranslator.translate(_:from:to:)`), so
both providers produce the same shape.

While a long text is in flight, the translation pane shows the chunks already translated and
"Translating part n of m". Copy and paste stay disabled until the whole text has arrived.

## Interaction

The panel opens at 960 × 560 points (minimum 680 × 420). The header holds text size, expand, settings,
keep-on-top and close. Below it, the source and target language menus sit around Swap, with Translate
at the end. Source and translation are two cards, side by side from 820 points wide and stacked below
that. Each card's header carries its own tools: the source card shows a character and paragraph count
(and how many parts a long text is sent in), history arrows, clear, read clipboard and copy; the
translation card has the bilingual toggle, copy and paste.

The translation is a read-only native text view, so long output selects, scrolls and copies like a
document; it keeps the reader's scroll position while chunks arrive. **Show Side by Side** interleaves
each source paragraph, in secondary ink, above its translation. ⌘− and ⌘= change the text size of both
cards between 12 and 26 points. **Expand** grows the panel to most of the screen it is on, and
**Restore Size** returns it to where it was.

Return translates; Shift-Return inserts a newline without consuming IME composition.
⌘Return also translates, ⌘⇧C copies the result, and ⌘⇧Return pastes to the captured app.
The arrows or ⌥↑/⌥↓ recall session history. The pin keeps the panel open when focus leaves it.
Escape dismisses the panel. The gear opens inline credential settings.

Source Auto Detect is Baidu's `auto`. Target Auto is an explicit Chinese/English convenience:
NaturalLanguage detects the input locally when source is automatic, Chinese varieties target English,
and other input targets Simplified Chinese. A manually selected target bypasses that policy. The footer
shows the provider and the language codes it resolved. Swap uses resolved languages and, if available,
the translated text as the new source. It refuses an unresolved automatic direction.

Apple's translator uses `TranslationLanguage.apple` to map the panel's Baidu codes (`jp` → `ja`,
`cht` → `zh-Hant`, …); Cantonese has no Apple equivalent, so choosing it cannot fall back. Apple uses
installed language pairs only — a missing pair reports where to download it, as the Quick Action does.

The API signs the original UTF-8 text using Baidu's mandated MD5 of APP ID + text + salt + secret, then
form-encodes the fields. A literal plus sign must be encoded as `%2B`. The pure harness checks the
published signing example, reserved characters, multibyte limits, chunking, blank-line alignment, the
fallback rule, language mapping, error and malformed responses, automatic targeting and bounded
history. `translation-session-test` compiles the shipped coordinator with isolated service doubles to
verify cancelled requests, late replies, language changes, close/reopen, delayed selection capture,
the Apple fallback after a Baidu failure, translating without credentials and late fallback results.

## Manual verification

Open both commands in Chinese and English appearances. Verify focus, Return versus Shift-Return and
Chinese IME confirmation; resize across the side-by-side width; expand and restore; change text size;
toggle bilingual view; open both language menus; pin and switch apps; navigate history; edit during a
slow request and close/reopen before it completes. Paste a text over 6000 bytes and watch it arrive in
parts. Configure real Baidu credentials to verify live translation, signature/credit/rate-limit errors
and selection/paste in Safari, a text editor and an app that cannot expose its selection; remove them,
or go offline, to see Apple answer with the reason in the footer. These need credentials, installed
Apple language pairs and app-level Accessibility grants and are not implied by a passing build or
mocked harness.
