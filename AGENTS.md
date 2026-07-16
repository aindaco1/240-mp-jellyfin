# 240-mp-jellyfin Development Guidelines

240-mp-jellyfin is a macOS Apple Silicon fork of 240-MP. It keeps the retro VHS/CRT-style Qt 6 + QML shell, keeps Local, Loop, Retro, and Tumblr, hides Plex, adds Jellyfin as the primary server-backed module, and adds a Funbox-backed Karaoke queue.

**Playback engine**: the app launches `mpv` as a subprocess through `MpvController`. Local track probing uses `ffprobe`. CMake downloads pinned, checksum-verified standalone `yt-dlp` and Deno helpers for YouTube extraction. Packaged macOS apps bundle all four helpers; end users do not need system copies.

---

## Build & Run

```bash
# First time / after CMakeLists.txt changes:
cmake -B build -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt . && cmake --build build

# Incremental:
cmake --build build

# Run:
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

For packaging, CI, and config paths, see **[BUILDING.md](BUILDING.md)** and **[INSTALL.md](INSTALL.md)**.

---

## Where Things Live

| If you need... | Read |
|---|---|
| Architecture, module anatomy, `manifest.json`, `AppCore`, `registerModule`, backends, QML navigation, playback, config shape | **[ARCHITECTURE.md](ARCHITECTURE.md)** |
| Contribution principles, testing, coding style | **[CONTRIBUTING.md](CONTRIBUTING.md)** |
| macOS build, run, package, release workflow, config paths | **[BUILDING.md](BUILDING.md)** |
| End-user macOS install/update/uninstall | **[INSTALL.md](INSTALL.md)** |
| Token handling and security-sensitive areas | **[SECURITY.md](SECURITY.md)** |
| User-facing change history | **[CHANGELOG.md](CHANGELOG.md)** |
| Planned work and improvement ideas | **[ROADMAP.md](ROADMAP.md)** |

---

## Key Facts

- CMake intentionally fails on non-macOS hosts.
- User-facing modules are `jellyfin`, `karaoke`, `retro_tv`, `tumblr_screensaver`, `local_files`, and `ambient_mode`, displayed in that order as Jellyfin, Karaoke, Retro, Tumblr, Local, and Loop.
- Plex remains in the source tree but is hidden by `modules/plex/manifest.json`.
- Modules are discovered from `modules/*/manifest.json`; a backend module adds one `registerModule(...)` call in `src/main.cpp`.
- `registerModule` wires optional backend signals/slots by introspection: `dynamicOptionsReady`, `authStateChanged`, and `onSettingChanged`.
- Every module's QML entry point is `Root.qml`. Views are `FocusScope`s that pass state via `navParams` and communicate through `navigateTo` / `goBack`.
- Size QML layouts with `root.sh` / `root.sw`.
- Config is `config.json` under `~/Library/Application Support/240-mp-jellyfin/`.
- Jellyfin auth is `jellyfin_auth.json`; passwords are never persisted.
- Karaoke stores a non-secret 24-hour catalog cache, persistent queue, and generated playback playlist under the same app data directory.
- Signed releases update through `UpdateManager`; never weaken its SHA-256, notarization, Developer ID team, bundle ID, version, or arm64 checks.
- Jellyfin TV playback negotiates PlaybackInfo, reports session progress, can retry through transcoding, and optionally uses server Media Segments for intro/outro skipping.
- Do not log tokens, passwords, full auth headers, or token-bearing URLs.
