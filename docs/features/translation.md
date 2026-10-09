# Quick Translate

A native, resizable floating panel for Baidu General Translation, separate from the existing
Apple-powered Quick Action. **Quick Translate** opens an editable source; **Translate Selected Text**
reads the app behind the palette and translates immediately when credentials are configured.
Both commands are in Settings → Commands, where shortcuts and aliases can be assigned.

## Invariants

- `AppCore` owns `TranslationCoordinator`. Views receive it through the environment. Closing the panel
  or terminating cancels owned work; request generations and panel-session identities reject late results.
- `BaiduTranslationService` uses a private ephemeral URL session without URL cache, cookies or credential
  storage. Requests are HTTPS POST with a 15-second timeout and no automatic retries.
- APP ID and secret are stored together in the channel-specific `baidu-translation` Keychain scope.
  They are never settings-file or backup entries. No credentials or translations are logged.
- Source, result, language selections, pin state and the last 20 successful translations are session-only.
  History never goes to disk. Editing source or language cancels and invalidates the previous result.
- The destination application is captured before opening the panel, and never becomes Tinycast itself.
  Selected-text capture and delivery use the existing permission-checked text-injection services.
  Failed delivery copies the translation and reports it; no unrequested paste occurs.
- `Model/` stays Foundation-only. Language codes, UTF-8 limits, response decoding and bounded history
  compile directly in `translation-test`.

## Interaction

The panel has source text above two side-by-side language menus, then a selectable translation and
copy/paste controls. Return translates; Shift-Return inserts a newline without consuming IME composition.
⌘Return also translates, ⌘⇧C copies the result, and ⌘⇧Return pastes to the captured app.
The arrows or ⌥↑/⌥↓ recall session history. The pin keeps the panel open when focus leaves it.
Escape dismisses the panel. The gear opens inline credential settings.

Source Auto Detect is Baidu's `auto`. Target Auto is an explicit Chinese/English convenience:
NaturalLanguage detects the input locally when source is automatic, Chinese varieties target English,
and other input targets Simplified Chinese. A manually selected target bypasses that policy. The footer
shows the language codes returned by Baidu. Swap uses resolved languages and, if available, the translated
text as the new source. It refuses an unresolved automatic direction.

The API signs the original UTF-8 text using Baidu's mandated MD5 of APP ID + text + salt + secret, then
form-encodes the fields. A literal plus sign must be encoded as `%2B`. Requests reject empty input and
inputs larger than 6000 UTF-8 bytes. The pure harness checks the published signing example, reserved
characters, multibyte limits, error and malformed responses, automatic targeting and bounded history.
`translation-session-test` compiles the shipped coordinator with isolated service doubles to verify
cancelled requests, late replies, language changes, close/reopen and delayed selection capture.

## Manual verification

Open both commands in Chinese and English appearances. Verify focus, Return versus Shift-Return and
Chinese IME confirmation; resize with long source and result; open both language menus; pin and switch
apps; navigate history; edit during a slow request and close/reopen before it completes. Configure real
Baidu credentials to verify live translation, signature/credit/rate-limit errors and selection/paste in
Safari, a text editor and an app that cannot expose its selection. These need credentials and app-level
Accessibility grants and are not implied by a passing build or mocked harness.
