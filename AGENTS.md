# 240-mp-jellyfin Development Guidelines

240-mp-jellyfin is a macOS Apple Silicon fork of 240-MP. It keeps the retro VHS/CRT-style Qt 6 + QML shell, keeps Local Files and Ambient Mode, hides Plex, and adds Jellyfin as the primary server-backed module.

**Playback engine**: the app launches `mpv` as a subprocess through `MpvController`. Local track probing uses `ffprobe`. Development builds can use Homebrew `mpv` and `ffprobe`; packaged macOS apps bundle both helpers and their non-system dynamic libraries.

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

---

## Key Facts

- CMake intentionally fails on non-macOS hosts.
- User-facing modules are `jellyfin`, `local_files`, and `ambient_mode`.
- Plex remains in the source tree but is hidden by `modules/plex/manifest.json`.
- Modules are discovered from `modules/*/manifest.json`; a backend module adds one `registerModule(...)` call in `src/main.cpp`.
- `registerModule` wires optional backend signals/slots by introspection: `dynamicOptionsReady`, `authStateChanged`, and `onSettingChanged`.
- Every module's QML entry point is `Root.qml`. Views are `FocusScope`s that pass state via `navParams` and communicate through `navigateTo` / `goBack`.
- Size QML layouts with `root.sh` / `root.sw`.
- Config is `config.json` under `~/Library/Application Support/240-mp-jellyfin/`.
- Jellyfin auth is `jellyfin_auth.json`; passwords are never persisted.
- Do not log tokens, passwords, full auth headers, or token-bearing URLs.
