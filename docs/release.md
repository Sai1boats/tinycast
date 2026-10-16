# Release

How a build reaches a user. The local development loop is in [development.md](development.md);
the signing identity itself is in [signing.md](signing.md).

## Packaging a DMG locally

```sh
./Scripts/build-dmg.sh            # -> build/Tinycast-<version>.dmg (version from project.yml)
./Scripts/build-dmg.sh 0.5.7      # -> build/Tinycast-0.5.7.dmg
```

It builds a Release `Tinycast.app`, verifies the nested signatures and runtime entitlements, and packs
it with an `/Applications` symlink. Signing defaults to `Tinycast Self-Signed`. To update an existing
local installation signed with another identity, set `CODE_SIGN_IDENTITY` to that identity and
`TINYCAST_BUNDLE_IDENTIFIER` to the installed bundle identifier. `TINYCAST_DERIVED_DATA_PATH` optionally
selects a separate build directory. These overrides apply to the build invocation and preserve the
project defaults. Official per-channel releases are built by CI, below.

## Required local completion

**Every application development task finishes by packaging and replacing the version currently
installed on this system.** This is part of delivering the change, without a separate packaging or
installation request. An explicit user instruction to defer or skip installation takes precedence.
This local delivery does not publish a GitHub release or update a Homebrew tap.

1. Complete the pre-install checks in the [definition of done](testing.md#definition-of-done):
   harnesses, lint, pure layer check, Debug build with no new warnings, updated docs and relevant
   manual checks. For a UI change, inspect native rendering and alignment in both appearances and at
   supported window sizes. The package/install check is completed by the remaining steps below.
2. Locate the current installed app, normally `/Applications/Tinycast.app`. Read its version, bundle
   identifier, signing identity and designated requirement. Build a signed Release DMG with
   `Scripts/build-dmg.sh`, using the installed identity as `CODE_SIGN_IDENTITY` and its bundle
   identifier as `TINYCAST_BUNDLE_IDENTIFIER`. Use `TINYCAST_DERIVED_DATA_PATH` for a separate local
   Release directory when needed. Choose a version that identifies the new build; do not change the
   installed channel or substitute a differently signed Debug app.
3. Verify the app and nested helpers with `Scripts/verify-signature.sh` and verify the DMG with
   `hdiutil verify`. Check the app icon and bundle metadata, and confirm the new app satisfies the
   installed app's designated requirement before replacing anything.
4. Back up the installed bundle under `build/backups/` with its version and a timestamp. Verify the
   backup, stage the new bundle on the destination filesystem, then gracefully quit the current app.
   Replace the whole app bundle with rollback available if installation fails. Preserve preferences,
   Application Support data, caches and existing permissions; do not reset TCC or change the bundle
   identifier. Keep the verified backup after success.
5. Reopen the app from the installed path. Verify its version, code signature and executable against
   the signed build, confirm the new process stays running, and smoke-test the changed behavior.
   If replacement or launch fails, restore and reopen the verified backup where possible, then report
   the failure rather than claiming completion. Missing signing credentials or a failed prerequisite
   must be reported as an incomplete delivery.
6. Report the installed version and path, DMG path, backup path and verification results. A compiled
   app, an uninstalled DMG, or an unverified launch is not a completed delivery.

## App icon

`Tinycast/tinycast.icon` is an Icon Composer package. `project.yml` declares `.icon` as a file
resource so XcodeGen passes the entire package to the asset compiler. Treating it as a group copies
its JSON and SVG separately and leaves the installed app without an icon. Keep the asset compiler's
app-icon name set to `tinycast`, and verify the built bundle contains `tinycast.icns` and its
`CFBundleIconFile` entry before packaging.

## Signing & Gatekeeper

Both local builds and CI releases sign with the same stable `Tinycast Self-Signed` identity, not an
Apple Developer ID — so macOS quarantines a directly-downloaded DMG. The Homebrew cask strips that
automatically; direct downloaders run `xattr -dr com.apple.quarantine "…/Tinycast.app"` once. Full
details in [signing.md](signing.md).

## Manual installation

This build has no in-app updater. Local development uses the mandatory
[completion sequence above](#required-local-completion): package, verify, back up, quit, replace,
reopen and check the installed app. Preserve its bundle identifier and signing identity so its channel
and permissions remain consistent.

The upstream release workflow below also produces ZIP assets for external distribution. Those assets
are not discovered, downloaded or installed by this app.

## Pull request review

There is no CI workflow. CodeRabbit reviews every PR against `.coderabbit.yaml`: it runs SwiftLint
with `.swiftlint.yml`, annotates the diff and applies the pre-merge checks. It is a reviewer, not a
gate — it neither runs the harnesses nor builds the app, so the whole bar in
[testing.md](testing.md#definition-of-done) is run locally before a PR is opened.

## Releasing

`.github/workflows/release.yml` builds and publishes a DMG from GitHub Actions, no local machine
needed. Run it from the **Actions** tab (`Release` → **Run workflow**) and pick:

- **channel** — `beta` or `stable`. Each builds a distinct app (`Tinycast Beta.app` / `Tinycast.app`)
  with its own bundle id, alongside the local `Tinycast Dev.app`. Beta gets an auto-incrementing
  `-beta.N` suffix (`N` = the Actions run number) so re-running never collides; stable ships the
  version as-is.
- **version** — base semver, e.g. `0.2.0`.

It builds on a `macos-26` runner with Xcode 26 and publishes a GitHub Release tagged
`v<full-version>` with a versioned DMG and zip asset, marked prerelease for beta. On success it also
bumps the matching cask in the tap and announces the release on Discord. A stable run also
dispatches the Website workflow, because the site reads the latest version and the
[changelog](https://tinycast.dev/changelog/) from GitHub at build time.

A stable run then fans out to a second job, `universal`, which rebuilds the same commit with
`ARCHS="arm64 x86_64"` and attaches `Tinycast-Universal-<version>.dmg` / `.zip` to the release the
first job created, then bumps `tinycast-universal`. macOS 26 is the last release that boots on Intel,
and those Macs need both slices. Both jobs pin `ARCHS` explicitly and assert the slices on *every*
shipping binary — the app, `ClipboardTextHelper` and `Tinycast Dictation`: trusting `ARCHS_STANDARD` is what
shipped a thin arm64 build to Intel users once already, and it also keeps the Apple silicon download
from silently gaining a slice it never needs. A thin helper inside a universal app is the quiet form
of the same bug: the app boots on Intel and only clipboard OCR or dictation stops working.

Channel builds override `TINYCAST_BUNDLE_IDENTIFIER`, not the target-wide `PRODUCT_BUNDLE_IDENTIFIER`.
The Dictation helper derives its own identifier with a `.dictation` suffix; signature verification
checks that its bundle and signing identifiers agree and remain distinct from the main app.

### Release notes

`Scripts/release-notes.sh` composes the release body, and CI runs it just before `gh release create`.
It is safe to run by hand against any tag — it only reads:

```sh
CHANNEL=beta TAG=v0.9.13-beta.61 ./Scripts/release-notes.sh /tmp/body.md /tmp/discord.md
```

The changelog itself comes from GitHub's own release-notes API, which lists every merged PR with its
author and number — so contributors are credited without anyone maintaining a `CHANGELOG.md`, and
without Conventional Commits. **Nothing is ever committed to this repo**: the tag is created
server-side by `gh release create`, and no release, bot or version-bump commit exists.

Two details the script exists for:

- **The previous tag is picked per channel.** Beta and stable tags interleave on `main` — the same
  commit can carry both — so "the previous release" is only ever right within one channel. A stable
  release therefore spans every beta since the last stable.
- **The body is split by `<!-- tinycast:install -->`.** Everything above it is the changelog;
  everything below is the Homebrew and quarantine text for manual installation. Full PR URLs are
  shortened to `#304`, which still autolinks on the web.

The Discord announcement carries the same changelog, truncated to fit Discord's component limit, and
pings `@everyone`.

### Homebrew tap automation

Each job's final step rewrites the `version` + `sha256` of its cask (`tinycast`, `tinycast@beta` or
`tinycast-universal`) in the [`homebrew-tinycast`](https://github.com/abue-ammar/homebrew-tinycast) tap
and pushes. It needs a `HOMEBREW_TAP_TOKEN` repo secret — a fine-grained PAT with **Contents:
read/write** on the tap repo. Without the secret the step logs a warning and skips; the release still
publishes. The `sed` is anchored to `^  version` / `^  sha256`, so a cask's two-space indent on those
lines is load-bearing.

Both stable casks install `Tinycast.app` under `com.tinycast.app`, so they `conflicts_with` one
another and Homebrew routes each Mac by `depends_on`: `tinycast` requires `arch: :arm64`, and
`tinycast-universal` takes the Intel Macs.
