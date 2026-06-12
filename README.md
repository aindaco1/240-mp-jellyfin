# 240-mp-jellyfin

240-mp-jellyfin is a macOS Apple Silicon fork of 240-MP: a retro VCR-style media shell built with C++ Qt 6 and QML. The fork keeps the CRT/240p-inspired interface, Local Files playback, and Ambient Mode, then adds Jellyfin as the main server-backed media module.

The app is a browsing shell, not an embedded video renderer. It launches `mpv` as a subprocess for playback and uses `ffprobe` to inspect local audio/subtitle tracks. Development builds use Homebrew tools from `PATH`; packaged macOS apps bundle `mpv`, `ffprobe`, and their non-system dynamic libraries so end users do not need Homebrew runtime dependencies.

## Supported Platform

- Apple Silicon macOS only.
- CMake intentionally fails on non-macOS hosts.
- Intel macOS, Raspberry Pi OS, and Linux packaging are out of scope for this fork.

## Current Modules

### Jellyfin

- Password login and Jellyfin Quick Connect.
- Movie libraries only for the current implementation.
- Large movie libraries load progressively in 250-item pages.
- Live title filter narrows the list as you type.
- Accent-insensitive filtering, so names with characters like `e` and `é` match naturally.
- Direct-play movie playback through mpv.
- Resume prompt based on Jellyfin playback position.
- Audio and subtitle selection before playback.
- External Jellyfin subtitle URLs are loaded through authenticated mpv requests without putting access tokens in media URLs.

Not yet implemented: TV/music libraries, Continue Watching hubs, playback progress reporting back to Jellyfin, watched-state updates, and transcoding fallback.

### Local Files

- Folder browsing.
- Common video file support: `mp4`, `mkv`, `avi`, `mov`, `m4v`, `webm`, `wmv`, `flv`, `f4v`, `mpg`, `mpeg`, `vob`.
- `m3u` and `m3u8` playlists.
- Loop and shuffle playback options.
- Resume history.
- Audio and subtitle selection before playback.
- Sidecar subtitle discovery for common subtitle formats.

### Ambient Mode

- Looping background video playback.
- Optional separate audio playlist.
- Kept from the original project as a first-class module.

### Plex

The original Plex module remains in the source tree as a reference implementation, but its manifest is marked hidden so it does not appear in normal module discovery or Settings. It can be removed after Jellyfin reaches the desired parity.

## Build And Run

See [BUILDING.md](BUILDING.md) for the full build, run, packaging, and release workflow.

Quick macOS development build:

```bash
brew install cmake qt mpv ffmpeg
cmake -B build -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt .
cmake --build build
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

## Install

See [INSTALL.md](INSTALL.md). The release artifact is a macOS Apple Silicon DMG containing `240-mp-jellyfin.app`.

## Configuration

User configuration is stored outside the app bundle:

```text
~/Library/Application Support/240-mp-jellyfin/
  config.json
  jellyfin_auth.json
```

`jellyfin_auth.json` stores the Jellyfin server URL, access token, user ID, username, server identity, and client device ID. Passwords are not persisted.

## Security Notes

- Jellyfin access tokens are stored with owner read/write permissions only.
- Jellyfin playback tokens are sent to mpv through a temporary private mpv config include instead of command-line header arguments.
- Jellyfin stream URLs do not include `api_key` tokens.
- Playback logs redact known token query parameters.

## License

This project remains licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for the full text.

If you distribute a modified version, you must also distribute it under GPL-3.0 and make the source available.
