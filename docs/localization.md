# Interface language

Tinycast offers **Follow System**, **简体中文**, and **English** in **Settings → General → Language**.
The default follows macOS. Changing the selection takes effect after quitting and reopening Tinycast;
this keeps SwiftUI, AppKit menus, and system panels in the same language. It does not change macOS,
input sources, dictation language, or the language used by Quick Actions translation.

`AppSettings.language` persists the selection in the running bundle's defaults domain. Its setter
writes or removes that domain's `AppleLanguages` override. Debug and Release remain separate.
The setting is included in settings backups and the opt-in JSON mirror as `general.language`, with
values `system`, `en`, and `zh-Hans`. File imports use the same setter and also require a restart.

## Resources and boundaries

English source text is the resource key. Both languages live under `Tinycast/Resources/{en,zh-Hans}.lproj`:
`Localizable.strings` for interface copy, `InfoPlist.strings` for system permission explanations.
Launcher editor forms, the custom command library, Hyper Key diagnostics and dictation download
progress follow the same language selection. Native form inputs receive localized labels and
placeholders; templates, script arguments and folder names stay canonical. AI refusal headers are
localized at the HTTP service boundary while the provider's own message remains unchanged.

Use `String(localized:)` for app-owned literals, including complete interpolated sentences, before
passing them into custom controls. Keep format argument types and positions identical in translations.
`SWIFT_EMIT_LOC_STRINGS` is enabled so Xcode also records compiler-extracted localization keys.

Model files retain canonical text and do not read bundles or the current language. Their consumers
localize known built-in labels at presentation. Built-in launcher entries are localized when indexed,
with the original English name retained as an alternate search title. IDs, shortcuts, aliases, saved
content, file paths, protocols, and calculation grammar remain stable.

Settings anchors and row targets retain source-language titles. Their views localize the labels;
search matches both translated labels and source labels, and breadcrumbs localize section names.
User-authored names, note contents, chat messages, application names, and third-party extension content
remain owned by their respective sources. The extension host's own controls and messages are localized.

## Verification

`./Scripts/run-tests.sh localization-test` checks resource loading, interpolation, permission copy,
and language override changes against an isolated preferences suite. `node Scripts/check-localizations.js`
checks matching resource keys and format argument signatures; lint runs it too.

Before shipping, reopen the app in each language and with Follow System. Check Settings search and
its jump-to-row behavior, launcher search in Chinese and English, menu-bar actions, clipboard filters,
notes, snippets, calendar, window management, AI, and the extension host. Verify that user-entered
English titles remain unchanged and that returning to English restores the interface after restart.
