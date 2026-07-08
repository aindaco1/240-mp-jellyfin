# 240-mp-jellyfin

240-mp-jellyfin is a macOS Apple Silicon fork of 240-MP: a retro VCR-style media shell built with C++ Qt 6 and QML. The fork keeps the CRT/240p-inspired interface, Local playback, Loop, Retro decade feeds, and a Tumblr image screensaver, then adds Jellyfin as the main server-backed media module.

The app is a browsing shell, not an embedded video renderer. It launches `mpv` as a subprocess for playback and uses `ffprobe` to inspect local audio/subtitle tracks. Development builds use Homebrew tools from `PATH`; packaged macOS apps bundle `mpv`, `ffprobe`, and their non-system dynamic libraries so end users do not need Homebrew runtime dependencies.

## Supported Platform

- Apple Silicon macOS only.
- CMake intentionally fails on non-macOS hosts.
- Intel macOS, Raspberry Pi OS, and Linux packaging are out of scope for this fork.

## Current Modules

### Jellyfin

- Password login and Jellyfin Quick Connect.
- Movie libraries and TV show libraries.
- TV browsing through shows, seasons, episodes, then the same metadata, track-selection, and playback flow used for movies.
- Large movie and TV lists load progressively in 250-item pages.
- Live title filter narrows the list as you type.
- Accent-insensitive filtering, so names with characters like `e` and `é` match naturally.
- Direct-play movie and episode playback through mpv.
- Resume prompt based on Jellyfin playback position.
- Audio and subtitle selection before movie and episode playback.
- External Jellyfin subtitle URLs are loaded through authenticated mpv requests without putting access tokens in media URLs.

Not yet implemented: music libraries, Continue Watching hubs, playback progress reporting back to Jellyfin, watched-state updates, and transcoding fallback.

### Retro

- MyRetroTVs-backed feeds for the 50s, 60s, 70s, 80s, 90s, and 00s.
- Fullscreen mpv playback of decoded YouTube clips, with no TV-frame overlay.
- Keyboard channel surfing, clip skipping, feed filtering, and decade jumping.
- CRT-style noise, glow, black-and-white, and static transition effects.
- Home-screen order places Retro between Jellyfin and Local.

### Local

- Folder browsing.
- The first view shows the active media directory, defaulting to `~/Desktop`.
- Common video file support: `mp4`, `mkv`, `avi`, `mov`, `m4v`, `webm`, `wmv`, `flv`, `f4v`, `mpg`, `mpeg`, `vob`.
- `m3u` and `m3u8` playlists.
- Loop and shuffle playback options.
- Resume history.
- Audio and subtitle selection before playback.
- Sidecar subtitle discovery for common subtitle formats.

### Loop

- Looping background video playback.
- Optional separate audio playlist.
- The first view shows the active media directory, defaulting to `~/Desktop`.
- Kept from the original project as a first-class module.

### Tumblr

- Public Tumblr URL input, defaulting to `https://pixelskylines.tumblr.com/` for quick testing.
- Image discovery through Tumblr's public `/api/read/json` feed pages.
- Fullscreen image montage that shuffles the image deck and does not repeat until every discovered image has been shown.
- Retro 90s-style QML transitions, including falling blocks built from clipped pieces of the incoming image.

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

## Project Docs

- [CHANGELOG.md](CHANGELOG.md) records user-facing changes.
- [ROADMAP.md](ROADMAP.md) tracks planned work and improvement ideas.
- [ARCHITECTURE.md](ARCHITECTURE.md) explains the module, playback, and backend structure.
- [CONTRIBUTING.md](CONTRIBUTING.md) covers contribution and testing expectations.

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
