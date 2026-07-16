# Building 240-mp-jellyfin

This fork is macOS-only. CMake intentionally fails configuration on non-macOS hosts.

## macOS (ARM)

### Prerequisites (one-time)

**Set up Build tools:**

```bash
brew install cmake
```

**Install Qt 6.*:**

```bash
brew install qt
```

**Install runtime helpers for development and packaging:**

```bash
brew install mpv ffmpeg
```

240-mp-jellyfin uses mpv as an external subprocess for video playback, `ffprobe` for local audio/subtitle track probing, and `ffmpeg` to merge high-quality Karaoke prefetches. Development runs can use Homebrew copies from `PATH`. Packaged apps embed all three helpers and their non-system dynamic libraries during `cmake --install`.

CMake also downloads pinned Apple Silicon-compatible Deno and standalone universal `yt-dlp` release assets, verifies their SHA-256 checksums, and embeds them with their license files. These power Karaoke catalog extraction and mpv's YouTube handoff without relying on a user's Python, JavaScript runtime, yt-dlp, or Homebrew installation. Maintainers can test a local helper build with `-DYT_DLP_EXECUTABLE_OVERRIDE=/path/to/yt-dlp` or `-DDENO_EXECUTABLE_OVERRIDE=/path/to/deno`; release builds should use the pinned defaults.

Jellyfin playback sends authentication headers to mpv through a temporary owner-only mpv include file. Tokens are not placed in normal Jellyfin stream URLs, and the app's playback launch log redacts known token query parameters.

### Get the source

```bash
git clone <your-fork-url>
cd 240-mp-jellyfin
```

### Build

**First time, and after any CMakeLists.txt changes:**

```bash
cmake -B build -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt . && cmake --build build
```

**For incremental builds:**

```bash
cmake --build build
```

### Run

The repository Run action and its terminal equivalent build first, stop any prior development instance, and open the app:

```bash
./script/build_and_run.sh
```

You can also double-click `build/240-mp-jellyfin.app` in Finder, or run the executable directly:

```bash
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

### Configuration

On macOS all user configuration is stored at:

```
~/Library/Application Support/240-mp-jellyfin/
  config.json          ← app and module settings
  jellyfin_auth.json   ← Jellyfin auth
  karaoke_catalog.json ← cached public sixteen-source Karaoke catalog (refreshed after 24 hours)
  karaoke_queue.json   ← persistent Karaoke queue
  karaoke_queue.m3u8   ← generated canonical playback URLs
```

Tumblr's current URL and favorites are ordinary module settings inside `config.json`; no separate database or credential file is used.

This directory is created automatically on first run. It is separate from the app itself, so deleting or rebuilding the app will not wipe your settings.

## Debugging & logs

240-mp-jellyfin logs to **stdout/stderr** via Qt's `qDebug` / `qWarning` (used throughout `AppCore`, `MpvController`, and the module backends).

### Running from source

Just run the binary in a terminal and the logs will print right there:

```bash
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

### mpv playback logs

During playback the app hands off to mpv as a subprocess (see [ARCHITECTURE.md → Playback Hand-off](ARCHITECTURE.md#playback-hand-off-mpvcontroller)). `MpvController` writes mpv's own output to a log file in the temp dir alongside its IPC socket (`/tmp/240-mp-jellyfin-mpv.sock`) — useful when a video will not play.

The app also writes a session marker to the same log. Known sensitive URL query keys such as `api_key`, `access_token`, `token`, and `X-Plex-Token` are redacted before that marker is written.

### Qt / QML debugging knobs

These environment variables help when the UI itself is misbehaving:

```bash
QT_LOGGING_RULES="qt.qml.*=true"   # verbose QML engine logging
QML_IMPORT_TRACE=1                 # trace QML import resolution (missing modules/components)
```

Set them inline, e.g. `QML_IMPORT_TRACE=1 APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin`.

## GitHub Actions

### Release credentials

The release workflow uses encrypted repository Actions secrets and App Store Connect API-key notarization. Configure these names without committing their values:

- `APPLE_CERT_P12_BASE64`: base64-encoded Developer ID Application certificate archive.
- `APPLE_CERT_PASSWORD`: password for that certificate archive.
- `APPLE_API_KEY_P8_BASE64`: base64-encoded App Store Connect API private key.
- `APPLE_API_KEY_ID`: App Store Connect API key ID.
- `APPLE_API_ISSUER_ID`: App Store Connect API issuer ID.

The workflow writes credentials only under the ephemeral runner temp directory, restricts the API key permissions, and deletes both the temporary keychain and credential files in an `always()` cleanup step. GitHub Actions are pinned to reviewed commit SHAs.

### How to trigger a build

Releases are built automatically when you push a version tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

And you can use pre-release tags to test CI without making a public release:

```bash
git tag v1.1.0-rc1
git push origin v1.1.0-rc1
```

Tags containing `-rc`, `-beta`, or `-alpha` are published as GitHub pre-releases.
The numeric portion of the tag must match the version declared in `CMakeLists.txt`; CI rejects mismatched tags before building. Public release notes are generated from that version's section in [CHANGELOG.md](CHANGELOG.md), so finalize the dated changelog entry before tagging.

If a tag push does not produce an Actions run, use **Actions → Release → Run workflow** and enter the existing tag. The manual path checks out that tag and runs the same version validation, tests, signing, notarization, and publication steps; it does not build arbitrary untagged source.

### What the workflow does

The intended workflow is a macOS Apple Silicon build:

| Job | Runner | Output |
|---|---|---|
| `build-macos-arm64` | `macos-26` (arm64) | `240-mp-jellyfin-<tag>-macOS-arm64.dmg` |

macOS jobs: installs Qt via the Qt CDN, configures CMake for `arm64`, downloads and verifies pinned yt-dlp/Deno, builds and tests, embeds all helpers, runs `macdeployqt`, prunes QML plugins not used by the app, verifies every Mach-O file under a stripped environment (including one live extraction from each Karaoke source), rejects `.DS_Store`, broken symlinks, and external load paths, Developer-ID signs the app and `.dmg`, notarizes and staples both, validates Gatekeeper acceptance, and publishes the DMG plus a SHA-256 checksum file.

The in-app updater consumes the same release. GitHub's API asset digest is mandatory, and the downloaded bundle must pass notarization, signature-team, bundle-ID, version, and arm64 checks before installation.

## Local Verification

Recommended checks before committing code changes:

```bash
cmake --build build
ctest --test-dir build --output-on-failure
qmllint -I views Main.qml views/*.qml views/Components/*.qml modules/jellyfin/views/*.qml modules/karaoke/views/*.qml modules/retro_tv/views/*.qml modules/local_files/views/*.qml modules/ambient_mode/views/*.qml modules/tumblr_screensaver/views/*.qml
git diff --check
```

The Karaoke backend suite skips its network integration case by default. Run it explicitly when changing the channel extractor or pinned helpers:

```bash
KARAOKE_LIVE_TEST=1 ./build/karaoke_backend_tests refreshesLiveCatalog
KARAOKE_LIVE_TEST=1 ./build/karaoke_backend_tests prefetchesLivePlaybackMedia
```

For packaging changes, also run a local install into a temporary prefix and confirm bundled helpers launch:

```bash
cmake --install build --prefix /tmp/240mp-jellyfin-install-test
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/mpv --version
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/ffmpeg -version
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/ffprobe -version
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/yt-dlp --version
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/deno --version
```

After running `macdeployqt`, use `scripts/macos_prune_qt_deployment.zsh` to retain only QML plugins found by `qmlimportscanner`, then run `scripts/macos_verify_bundle.zsh` before signing. The release workflow is the canonical invocation for both scripts.

### Cleaning Generated Artifacts

Preview ignored build output before removing it:

```bash
git clean -ndX
```

When the preview contains only disposable generated files, remove them and recreate the single development tree:

```bash
git clean -fdX
cmake -B build -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt .
cmake --build build
```

This retains tracked development scripts, CMake helpers, entitlements, source, and tests while removing old build/package trees, DMGs, logs, caches, and Finder metadata.

When applying hardened-runtime signatures, preserve the bundled Deno binary's
upstream entitlements. Sign standalone yt-dlp with
`packaging/yt-dlp.entitlements` because its PyInstaller launcher extracts and
loads its embedded Python runtime dynamically. Sign mpv with
`packaging/mpv.entitlements` because its LuaJIT engine generates executable
memory when loading playback scripts.

### Output

**While the workflow is running:**

Go to **Actions** → select the workflow run → each build job has an **Artifacts** section at the bottom where you can download that job's output before the release is published.

**After the workflow completes:**

Go to the repository on GitHub → **Releases** → select the release for the tag you set. The DMG is listed under Assets.
