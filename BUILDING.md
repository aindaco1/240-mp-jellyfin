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

Note: 240-mp-jellyfin uses mpv as an external subprocess for video playback and `ffprobe` for local audio/subtitle track probing. Development runs can use Homebrew tools from your `PATH`. Packaged macOS apps embed `mpv`, `ffprobe`, and their non-system dynamic libraries during `cmake --install` when both tools are available on the build machine, so end users do not need Homebrew runtime installs for playback or track probing.

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

You can either double-click `build/240-mp-jellyfin.app` in Finder, or run from the terminal:

```bash
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

### Configuration

On macOS all user configuration is stored at:

```
~/Library/Application Support/240-mp-jellyfin/
  config.json          ← app and module settings
  jellyfin_auth.json   ← Jellyfin auth
```

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

### How to trigger a build

Releases are built automatically when you push a version tag:

```bash
git tag v1.0
git push origin v1.0
```

And you can use pre-release tags to test CI without making a public release:

```bash
git tag v1.1-rc1
git push origin v1.1-rc1
```

Tags containing `-rc`, `-beta`, or `-alpha` are published as GitHub pre-releases.

### What the workflow does

The intended workflow is a macOS Apple Silicon build:

| Job | Runner | Output |
|---|---|---|
| `build-macos-arm64` | `macos-26` (arm64) | `240-mp-jellyfin-<tag>-macOS-arm64.dmg` |

macOS jobs: installs Qt via the Qt CDN, configures CMake for `arm64`, builds, embeds `mpv` and `ffprobe`, runs `macdeployqt` to embed Qt frameworks, codesigns, and packages as `.dmg`.

## Local Verification

Recommended checks before committing code changes:

```bash
cmake --build build
qmllint -I views modules/jellyfin/views/*.qml modules/retro_tv/views/*.qml modules/local_files/views/*.qml modules/ambient_mode/views/*.qml
git diff --check
```

For packaging changes, also run a local install into a temporary prefix and confirm bundled helpers launch:

```bash
cmake --install build --prefix /tmp/240mp-jellyfin-install-test
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/mpv --version
/tmp/240mp-jellyfin-install-test/240-mp-jellyfin.app/Contents/Resources/bin/ffprobe -version
```

### Output

**While the workflow is running:**

Go to **Actions** → select the workflow run → each build job has an **Artifacts** section at the bottom where you can download that job's output before the release is published.

**After the workflow completes:**

Go to the repository on GitHub → **Releases** → select the release for the tag you set. The DMG is listed under Assets.
