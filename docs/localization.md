# Interface language

Settings → General → Language offers English, German, Spanish, French, Japanese, Korean,
Portuguese, Russian and Simplified Chinese. A fresh installation selects the Mac's primary
language when supported, otherwise English. Changing it offers to relaunch Tinycast.
The per-app `AppleLanguages` list remains separate for Debug and Release and preserves an
existing English or Chinese selection. It does not change macOS or translation destinations.

The preference is included in backups and the settings.json mirror as `general.language`.
The supported values are `en`, `de`, `es`, `fr`, `ja`, `ko`, `pt`, `ru` and `zh-Hans`.

## Resources and boundaries

`Tinycast/Resources/Localizable.xcstrings` owns interface copy; `InfoPlist.xcstrings` owns
permission explanations. Upstream strings carry all nine languages. Fork-specific strings
retain English and Simplified Chinese and fall back to English in the other languages; their
catalog entries explicitly identify that scope. No duplicate `.strings` source tables are shipped.

Use native SwiftUI literal localization and `LocalizedStringResource` for controls that only
label app-owned content. Resolve resources through `resolved()`. Runtime strings, dialogs,
AppKit labels and error messages use `String(localized:)`. Keep complete sentences together
and preserve format argument types in translations.

Application names, user content, paths, protocols, IDs and third-party extension content are
never translated by Tinycast. Built-in commands retain their English names as alternate search
titles. Settings search also matches the source labels. System app and emoji indexing uses
macOS's preferred languages independently of Tinycast's interface language.

## Verification

`language-test` checks stored language selection, regional tags and supported fallbacks.
`localized-resource-test` checks resource resolution, while `localization-test` ensures the
fork's command labels retain Chinese translations in the catalog.
`node Scripts/check-localizations.js` validates translation coverage and format arguments for
each entry's supported languages. Lint runs the same check.

After changing copy, run `Scripts/sync-strings.sh` and translate newly extracted keys. Check
native Chinese and English rendering, Settings search, built-in English aliases, and unchanged
user-authored titles before shipping.
