# Contributing to 240-mp-jellyfin

240-mp-jellyfin is a focused macOS Apple Silicon fork of 240-MP. The goal is to keep the retro CRT-style media shell, keep Local, Loop, Retro, Tumblr, and Karaoke user-facing, and make Jellyfin the primary server-backed integration.

## Getting Started

1. Follow [BUILDING.md](BUILDING.md) to build and run on macOS.
2. Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing module, playback, settings, or auth behavior.
3. Work on a branch and open a pull request against `main` with a clear description and testing notes.

## Project Principles

1. **macOS only for now.** Do not add Raspberry Pi, Linux, or Intel macOS assumptions unless the supported-platform decision changes.
2. **Keep the retro CRT UI.** Use the existing keyboard-first QML patterns and size with `root.sh` / `root.sw`.
3. **Keep navigation simple.** Core browsing should work with arrow keys, Enter, Escape/Backspace, and Tab where forms need field navigation.
4. **Keep modules self-contained.** QML belongs under `modules/<name>/`; backend code belongs under `src/modules/<name>/`; module registration happens once in `src/main.cpp`.
5. **Do not add tracking or analytics.** Modules may call their intended API directly, but they should not report usage to a service controlled by contributors.
6. **Browse and hand off.** The app browses structured media, then hands playback to mpv. Do not replace mpv with embedded playback without a deliberate architecture decision.

## Current Module Direction

- `jellyfin` is the primary server module.
- `karaoke` (Karaoke), `retro_tv` (Retro), `tumblr_screensaver` (Tumblr), `local_files` (Local), and `ambient_mode` (Loop) stay user-facing.
- `plex` remains hidden as a reference until Jellyfin has enough parity to remove it.
- Jellyfin currently targets movie libraries and direct play first.

## Adding Or Changing A Module

A module is a folder under `modules/` with a `manifest.json` and QML views, plus an optional C++ backend.

1. Create `modules/<name>/manifest.json`, assets, and `views/Root.qml`.
2. Follow the router/list/detail patterns in [ARCHITECTURE.md](ARCHITECTURE.md#qml-view-patterns).
3. If the module needs C++, add `src/modules/<name>/<Name>Backend.h/.cpp`, add the `.cpp` to `CMakeLists.txt`, and register the backend once in `src/main.cpp`.
4. Use `appCore.get_setting()` / `save_setting()` for settings. Do not write `config.json` directly from QML.
5. Store module auth/state under the app data directory. Auth files containing tokens should use owner read/write permissions only.

## Code Style

- Match the style of the file you are editing.
- Keep changes scoped to the behavior being changed.
- Prefer existing helpers and module patterns over new abstractions.
- Add a new abstraction only when it removes meaningful duplication or matches an existing local pattern.
- Avoid logging secrets, tokens, passwords, full auth headers, or token-bearing URLs.

## Testing

Before opening a PR, run the checks that apply:

```bash
cmake --build build
ctest --test-dir build --output-on-failure
qmllint -I views Main.qml views/*.qml views/Components/*.qml modules/jellyfin/views/*.qml modules/karaoke/views/*.qml modules/retro_tv/views/*.qml modules/local_files/views/*.qml modules/ambient_mode/views/*.qml modules/tumblr_screensaver/views/*.qml
git diff --check
```

Manual checks for media changes:

- Build and run the app on Apple Silicon macOS.
- Navigate without a mouse.
- Confirm Jellyfin login, library loading, filtering, detail loading, and playback.
- Confirm Retro feed loading, channel surfing, filtering, static transitions, and mpv playback.
- Confirm Karaoke automatic/manual catalog refresh, live filtering, duplicate adds, persistence, reorder/move mode, clear confirmation, external-display playback, live queue edits, completed removal, and failed retention.
- Confirm Local browsing, track probing, sidecar subtitle discovery, and playback.
- Confirm Loop media directory display and looping playback.
- Confirm Tumblr URL loading, shuffled non-repeating image playback, and 90s-style transitions.
- Confirm app settings persist after restart.
- For packaging changes, run `cmake --install` into a temporary prefix and verify bundled `mpv`, `ffprobe`, `yt-dlp`, and Deno launch with a stripped `PATH`.

## AI Use

AI-assisted contributions are allowed, but contributors are responsible for understanding and testing the code they submit. Pull requests should describe meaningful AI involvement and the human review/testing performed before submission.

## License

By contributing, you agree your contributions are licensed under GPL-3.0. See [LICENSE](LICENSE).
